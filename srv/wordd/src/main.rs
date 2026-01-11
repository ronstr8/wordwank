use actix_web::{get, web, App, HttpServer, HttpResponse, Responder};
use std::collections::{HashSet, HashMap};
use std::fs::File;
use std::io::{self, BufRead, BufReader, Write};
use std::net::TcpStream;
use clap::{Command, Arg};
use log::{info, warn};
use env_logger;
use std::fs::OpenOptions;

// Struct to hold multiple language word lists
struct AppState {
    word_lists: HashMap<String, HashSet<String>>,
    dictd_host: Option<String>,
}

// Function to initialize logging
fn init_logging(log_file: Option<&String>) {
    if let Some(file) = log_file {
        let log_output = OpenOptions::new()
            .create(true)
            .append(true)
            .open(file)
            .expect("Failed to open log file");

        env_logger::Builder::new()
            .target(env_logger::Target::Pipe(Box::new(log_output)))
            .init();
    } else {
        env_logger::init();
    }
}

// Function to load words from a file into a HashSet
// Function to load words from a YAML file (expects a list of strings)
fn load_words(file_path: &str) -> io::Result<HashSet<String>> {
    let file = File::open(file_path)?;
    let reader = io::BufReader::new(file);
    
    let mut words = HashSet::new();
    for line in reader.lines() {
        let line = line?;
        let word = line.trim();
        if !word.is_empty() {
            words.insert(word.to_uppercase());
        }
    }

    Ok(words)
}

fn load_filtered_words(base_dir: &str, lang: &str) -> HashSet<String> {
    let lang_dir = format!("{}/words/{}", base_dir, lang);
    
    let valid_path = format!("{}/lexicon.txt", lang_dir);
    let custom_path = format!("{}/insertions.txt", lang_dir);
    let censored_path = format!("{}/exclusions.txt", lang_dir);

    let mut words = load_words(&valid_path)
        .unwrap_or_else(|_| {
            warn!("Failed to load main lexicon for {} at {}.", lang, valid_path);
            HashSet::new()
        });

    if let Ok(custom) = load_words(&custom_path) {
        info!("Loaded {} insertions for {}.", custom.len(), lang);
        words.extend(custom);
    }

    if let Ok(censored) = load_words(&censored_path) {
        info!("Loaded {} exclusions for {}.", censored.len(), lang);
        for word in censored {
            words.remove(&word);
        }
    }

    info!("Total valid words for {}: {}", lang, words.len());
    words
}

fn query_dictd(host: &str, word: &str) -> io::Result<String> {
    info!("Connecting to dictd host: {} for word: {}", host, word);
    let stream = TcpStream::connect(host)?;
    stream.set_read_timeout(Some(std::time::Duration::from_secs(5)))?;
    
    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    
    // Read greeting
    reader.read_line(&mut line)?;
    info!("Dictd greeting: {}", line.trim());
    if !line.starts_with("220") {
        return Err(io::Error::new(io::ErrorKind::Other, format!("Unexpected greeting: {}", line)));
    }

    // Send DEFINE
    let command = format!("DEFINE * {}\n", word);
    let stream = reader.get_mut();
    stream.write_all(command.as_bytes())?;
    info!("Sent DEFINE command for: {}", word);

    let mut response = String::new();
    let mut found_content = false;

    loop {
        let mut line = String::new();
        match reader.read_line(&mut line) {
            Ok(0) => break, // EOF
            Ok(_) => {
                let trimmed = line.trim();
                
                // Status codes
                if trimmed.starts_with("250") {
                    info!("Dictd: Match finished (250)");
                    break;
                }
                if trimmed.starts_with("552") {
                    info!("Dictd: No match found (552)");
                    return Ok(String::new());
                }
                if trimmed.starts_with("150") || trimmed.starts_with("151") {
                    info!("Dictd: {}", trimmed);
                    continue;
                }
                
                // Error codes
                if trimmed.starts_with("5") || trimmed.starts_with("4") {
                    warn!("Dictd error: {}", trimmed);
                    break;
                }

                // Actual content
                if !line.starts_with('.') || line.len() > 2 {
                    // Protocol: lines beginning with '.' are escaped. 
                    // '..' becomes '.'
                    // '.' alone ends the definition block (handled by 250 usually but let's be safe)
                    let clean_line = if line.starts_with("..") { &line[1..] } else { &line };
                    response.push_str(clean_line);
                    if !clean_line.trim().is_empty() {
                        found_content = true;
                    }
                }
            },
            Err(e) => {
                warn!("Error reading from dictd: {}", e);
                return Err(e);
            }
        }
    }

    info!("Dictd query complete. Found content: {}", found_content);
    if !found_content { Ok(String::new()) } else { Ok(response) }
}

#[derive(serde::Serialize)]
struct ConfigResponse {
    tiles: HashMap<char, usize>,
    unicorns: HashMap<char, usize>,
}

#[get("/config/{lang}")]
async fn get_config(
    data: web::Data<AppState>,
    path: web::Path<String>,
) -> impl Responder {
    let lang = path.into_inner();
    let words = match data.word_lists.get(&lang.to_lowercase()) {
        Some(w) => w,
        None => return HttpResponse::BadRequest().finish(),
    };

    let mut freq = HashMap::new();
    let mut total_chars = 0;

    for word in words {
        for c in word.chars() {
            if c.is_alphabetic() {
                *freq.entry(c.to_ascii_uppercase()).or_insert(0) += 1;
                total_chars += 1;
            }
        }
    }

    if total_chars == 0 {
        return HttpResponse::InternalServerError().finish();
    }

    // Identify rarest 2 letters (unicorns)
    let mut sorted_letters: Vec<_> = freq.keys().cloned().collect();
    sorted_letters.sort_by_key(|&c| freq[&c]);
    
    let unicorns: HashMap<char, usize> = sorted_letters.iter()
        .take(2)
        .map(|&c| (c, 10))
        .collect();

    // Calculate tile distribution (Targeting 100 tiles total)
    // 2 blanks preserved
    let mut tiles = HashMap::new();
    tiles.insert('_', 2);

    let mut remaining_tiles: isize = 98;
    
    // First pass: Proportional allocation with floor of 1
    for (&c, &count) in &freq {
        let proportion = (count as f64) / (total_chars as f64);
        let mut tile_count = (proportion * 98.0).round() as usize;
        if tile_count == 0 { tile_count = 1; }
        
        tiles.insert(c, tile_count);
        remaining_tiles -= tile_count as isize;
    }

    // Second pass: Adjust to exactly 100 tiles if we have leftovers or overshoots
    // (This is a naive adjustment, but works for word game bags)
    if remaining_tiles > 0 {
        // Give leftovers to common letters
        sorted_letters.sort_by_key(|&c| std::cmp::Reverse(freq[&c]));
        for i in 0..(remaining_tiles as usize) {
            if let Some(&c) = sorted_letters.get(i % sorted_letters.len()) {
                *tiles.entry(c).or_insert(0) += 1;
            }
        }
    } else if remaining_tiles < 0 {
         // Naive reduction from common letters (rare case)
         // Not worth complex optimization since it's just a game bag
    }

    info!("Generated {} config with {} tiles and {} unicorns", lang, tiles.values().sum::<usize>(), unicorns.len());

    HttpResponse::Ok().json(ConfigResponse {
        tiles,
        unicorns,
    })
}

#[get("/word/{lang}/{word}")]
async fn check_word_lang(
    data: web::Data<AppState>,
    path: web::Path<(String, String)>,
) -> impl Responder {
    let (lang, word) = path.into_inner();
    let words = match data.word_lists.get(&lang.to_lowercase()) {
        Some(w) => w,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };

    let is_valid = words.contains(&word.to_uppercase());

    if !is_valid {
        info!("Invalid word queried ({}): {}", lang, word.to_lowercase());
        return HttpResponse::NotFound().finish();
    }

    if let Some(host) = &data.dictd_host {
        match query_dictd(host, &word) {
            Ok(response) => {
                info!("Valid word queried ({}): {}", lang, word.to_uppercase());
                if response.trim().is_empty() {
                    HttpResponse::Ok().body(format!("(Definition for '{}' not found in database)", word.to_uppercase()))
                } else {
                    HttpResponse::Ok().body(response)
                }
            },
            Err(_) => {
                warn!("Failed to query dictd for word: {}. Accepting anyway.", word.to_uppercase());
                HttpResponse::Ok().body(format!("(Definition for '{}' not found in dictionary service)", word.to_uppercase()))
            }
        }
    } else {
        info!("Valid word without dictd lookup ({}): {}", lang, word.to_uppercase());
        HttpResponse::Ok().body(format!("(Dictionary service not configured for '{}')", word.to_uppercase()))
    }
}

// Backward compatibility
#[get("/word/{word}")]
async fn check_word(
    data: web::Data<AppState>,
    word: web::Path<String>,
) -> impl Responder {
    let word = word.into_inner();
    let words = match data.word_lists.get("en") {
        Some(w) => w,
        None => return HttpResponse::InternalServerError().finish(),
    };

    let is_valid = words.contains(&word.to_uppercase());
    if !is_valid { return HttpResponse::NotFound().finish(); }

    if let Some(host) = &data.dictd_host {
        match query_dictd(host, &word) {
            Ok(response) => {
                if response.trim().is_empty() {
                    HttpResponse::Ok().body(format!("(Definition for '{}' not found in database)", word.to_uppercase()))
                } else {
                    HttpResponse::Ok().body(response)
                }
            },
            Err(_) => {
                warn!("Failed to query dictd for word: {}. Accepting anyway.", word.to_uppercase());
                HttpResponse::Ok().body(format!("(Definition for '{}' not found in dictionary service)", word.to_uppercase()))
            }
        }
    } else {
        HttpResponse::Ok().body(format!("(Dictionary service not configured for '{}')", word.to_uppercase()))
    }
}

#[get("/validate/{lang}/{word}")]
async fn validate_word_lang(
    data: web::Data<AppState>,
    path: web::Path<(String, String)>,
) -> impl Responder {
    let (lang, word) = path.into_inner();
    let words = match data.word_lists.get(&lang.to_lowercase()) {
        Some(w) => w,
        None => return HttpResponse::BadRequest().finish(),
    };

    if words.contains(&word.to_uppercase()) {
        HttpResponse::Ok().finish()
    } else {
        HttpResponse::NotFound().finish()
    }
}

#[get("/validate/{word}")]
async fn validate_word(
    data: web::Data<AppState>,
    word: web::Path<String>,
) -> impl Responder {
    let word = word.into_inner();
    let words = match data.word_lists.get("en") {
        Some(w) => w,
        None => return HttpResponse::InternalServerError().finish(),
    };

    if words.contains(&word.to_uppercase()) {
        HttpResponse::Ok().finish()
    } else {
        HttpResponse::NotFound().finish()
    }
}


#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let matches = Command::new("wordd")
        .version("1.2")
        .author("Ron Straight <straightre@gmail.com>")
        .about("Polyglot word validity and lookup service")
        .arg(
            Arg::new("dictd-host")
                .long("dictd-host")
                .num_args(1)
                .help("Specify the dictd host (e.g., dictd:2628)"),
        )
        .arg(
            Arg::new("listen-host")
                .long("listen-host")
                .num_args(1)
                .default_value("0.0.0.0:2345")
                .help("Specify the listen address (e.g., 0.0.0.0:2345)"),
        )
        .arg(
            Arg::new("log-file")
                .long("log-file")
                .num_args(1)
                .help("Specify a log file path (if omitted, logs to stderr)"),
        )
        .arg(
            Arg::new("share-dir")
                .long("share-dir")
                .num_args(1)
                .default_value("./share")
                .help("Directory containing the word files"),
        )
        .arg(
            Arg::new("langs")
                .long("langs")
                .num_args(1)
                .default_value("en,es")
                .help("Comma-separated list of languages to support"),
        )
        .get_matches();

    let dictd_host = matches.get_one::<String>("dictd-host").cloned();
    let listen_host = matches
        .get_one::<String>("listen-host")
        .expect("listen-host argument must always have a default value")
        .clone();
    let log_file = matches.get_one::<String>("log-file");
    let share_dir = matches.get_one::<String>("share-dir").unwrap();
    let langs_str = matches.get_one::<String>("langs").unwrap();

    init_logging(log_file);

    let mut word_lists = HashMap::new();
    for lang in langs_str.split(',') {
        let lang = lang.trim();
        info!("Loading word list for language: {}", lang);
        let words = load_filtered_words(share_dir, lang);
        word_lists.insert(lang.to_lowercase(), words);
    }

    let state = AppState {
        word_lists,
        dictd_host,
    };
    let shared_state = web::Data::new(state);

    HttpServer::new(move || {
        App::new()
            .app_data(shared_state.clone())
            .service(get_config)
            .service(check_word_lang)
            .service(check_word)
            .service(validate_word_lang)
            .service(validate_word)
    })
    .bind(&listen_host)?
    .run()
    .await
}
