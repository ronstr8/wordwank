use actix_web::{get, web, App, HttpServer, HttpResponse, Responder};
use std::collections::{HashSet, HashMap};
use std::fs::File;
use std::io::{self, BufRead, BufReader, Write};
use std::sync::Arc;
use std::net::TcpStream;
use clap::{Command, Arg};
use log::{error, info, warn};
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
    
    let valid_path = format!("{}/valid-words.txt", lang_dir);
    let custom_path = format!("{}/custom-words.txt", lang_dir);
    let censored_path = format!("{}/censored-words.txt", lang_dir);

    let mut words = load_words(&valid_path)
        .unwrap_or_else(|_| {
            warn!("Failed to load main word list for {} at {}.", lang, valid_path);
            HashSet::new()
        });

    if let Ok(custom) = load_words(&custom_path) {
        info!("Loaded {} custom words for {}.", custom.len(), lang);
        words.extend(custom);
    }

    if let Ok(censored) = load_words(&censored_path) {
        info!("Loaded {} censored words for {}.", censored.len(), lang);
        for word in censored {
            words.remove(&word);
        }
    }

    info!("Total valid words for {}: {}", lang, words.len());
    words
}

fn query_dictd(host: &str, word: &str) -> io::Result<String> {
    let mut stream = TcpStream::connect(host)?;
    let command = format!("DEFINE * {}\n", word);
    stream.write_all(command.as_bytes())?;

    let reader = BufReader::new(stream);
    let mut response = String::new();

    for line in reader.lines() {
        let line = line?;
        if line.starts_with("250") {
            // End of definition marker
            break;
        }
        response.push_str(&line);
        response.push('\n');
    }

    Ok(response)
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
                HttpResponse::Ok().body(response)
            },
            Err(_) => {
                warn!("Failed to query dictd for word: {}. Accepting anyway.", word.to_uppercase());
                HttpResponse::Ok().finish()
            }
        }
    } else {
        info!("Valid word without dictd lookup ({}): {}", lang, word.to_uppercase());
        HttpResponse::Ok().finish()
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
            Ok(response) => HttpResponse::Ok().body(response),
            Err(_) => {
                warn!("Failed to query dictd for word: {}. Accepting anyway.", word.to_uppercase());
                HttpResponse::Ok().finish()
            }
        }
    } else {
        HttpResponse::Ok().finish()
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
            .service(check_word_lang)
            .service(check_word)
            .service(validate_word_lang)
            .service(validate_word)
    })
    .bind(&listen_host)?
    .run()
    .await
}
