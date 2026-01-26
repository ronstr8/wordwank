mod models;
mod utils;
mod services;

use actix_web::{get, web, App, HttpServer, HttpResponse, Responder};
use std::collections::HashMap;
use clap::{Command, Arg};
use log::info;
use std::fs::OpenOptions;
use rand::seq::SliceRandom;

use models::{AppState, LangInfo, ConfigResponse, RandQuery};
use utils::*;
use services::{word_loader, distribution, letter_classifier};

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














#[get("/langs")]
async fn get_langs(data: web::Data<AppState>) -> impl Responder {
    let langs: Vec<LangInfo> = data.supported_langs.iter().map(|code| {
        let name = match code.as_str() {
            "en" => "English",
            "es" => "Español",
            "fr" => "Français",
            "de" => "Deutsch",
            _ => code.as_str(),
        }.to_string();
        LangInfo { name, code: code.clone() }
    }).collect();

    HttpResponse::Ok().json(langs)
}



#[get("/config/{lang}")]
async fn get_config(
    data: web::Data<AppState>,
    path: web::Path<String>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    
    // Retrieve pre-computed values from AppState
    let bag = match data.letter_bags.get(&lang) {
        Some(b) => b.clone(),
        None => return HttpResponse::BadRequest().finish(),
    };

    let vowels = match data.vowel_sets.get(&lang) {
        Some(v) => v.clone(),
        None => return HttpResponse::BadRequest().finish(),
    };

    let unicorns = match data.unicorn_sets.get(&lang) {
        Some(u) => {
            // Convert unicorn letters to HashMap with standard value of 10
            u.iter().map(|&c| (c, 10)).collect::<HashMap<char, usize>>()
        },
        None => return HttpResponse::BadRequest().finish(),
    };

    // tiles is same as bag for backward compatibility
    let tiles = bag.clone();

    info!("Generated {} config with {} tiles, {} unicorns, and {} vowels", 
          lang, tiles.values().sum::<usize>(), unicorns.len(), vowels.len());

    HttpResponse::Ok().json(ConfigResponse {
        tiles,
        unicorns,
        vowels,
        bag,
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

    info!("Valid word queried ({}): {}", lang, word.to_uppercase());
    HttpResponse::Ok().body(format!("Valid word: {}", word.to_uppercase()))
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

    HttpResponse::Ok().body(format!("Valid word: {}", word.to_uppercase()))
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














#[get("/rand/langs/{lang}/letter")]
async fn rand_letter(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let bag = match data.letter_bags.get(&lang) {
        Some(b) => b,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };
    
    let letters = select_random_from_bag(bag, count);
    let output = letters.iter().map(|c| c.to_string()).collect::<Vec<_>>().join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}

#[get("/rand/langs/{lang}/vowel")]
async fn rand_vowel(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let vowels = match data.vowel_sets.get(&lang) {
        Some(v) => v,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };
    
    let selected = select_random_from_list(vowels, count);
    let output = selected.iter().map(|c| c.to_string()).collect::<Vec<_>>().join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}

#[get("/rand/langs/{lang}/consonant")]
async fn rand_consonant(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let consonants = match data.consonant_sets.get(&lang) {
        Some(c) => c,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };
    
    let selected = select_random_from_list(consonants, count);
    let output = selected.iter().map(|c| c.to_string()).collect::<Vec<_>>().join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}

#[get("/rand/langs/{lang}/unicorn")]
async fn rand_unicorn(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let unicorns = match data.unicorn_sets.get(&lang) {
        Some(u) => u,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };
    
    let selected = select_random_from_list(unicorns, count);
    let output = selected.iter().map(|c| c.to_string()).collect::<Vec<_>>().join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}

#[get("/rand/langs/{lang}/word")]
async fn rand_word(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let words = match data.word_lists.get(&lang) {
        Some(w) => w,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };
    
    // Get language-specific vowels for constraint validation
    let vowels = data.vowel_sets.get(&lang)
        .map(|v| v.as_slice())
        .unwrap_or(&['A', 'E', 'I', 'O', 'U']);
    
    let mut selected = Vec::new();
    let has_letters_constraint = query.letters.is_some();
    let has_rack_constraints = query.min_vowels.is_some() || query.min_consonants.is_some();
    
    if has_letters_constraint || has_rack_constraints {
        let mut rng = rand::thread_rng();
        let words_vec: Vec<&String> = words.iter().collect();
        let retries = 500; // Hardcoded for performance and security
        
        for _ in 0..count {
            for _ in 0..retries {
                if let Some(word) = words_vec.choose(&mut rng) {
                    let mut valid = true;
                    
                    // Check letters constraint
                    if let Some(available_letters) = &query.letters {
                        if !contains_only_letters(word, available_letters) {
                            valid = false;
                        }
                    }
                    
                    // Check vowel/consonant constraints
                    if valid && has_rack_constraints {
                        let (vowel_count, consonant_count) = count_vowels_consonants(word, vowels);
                        
                        if let Some(min_v) = query.min_vowels {
                            if vowel_count < min_v {
                                valid = false;
                            }
                        }
                        
                        if let Some(min_c) = query.min_consonants {
                            if consonant_count < min_c {
                                valid = false;
                            }
                        }
                    }
                    
                    if valid {
                        selected.push((*word).clone());
                        break;
                    }
                }
            }
        }
    } else {
        selected = select_random_words(words, count);
    }

    let output = selected.join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}


#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let matches = Command::new("wordd")
        .version("1.3")
        .author("Ron Straight <straightre@gmail.com>")
        .about("Polyglot word validity and lookup service")

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
                .default_value("en,es,fr")
                .help("Comma-separated list of languages to support"),
        )
        .arg(
            Arg::new("total-tiles")
                .long("total-tiles")
                .num_args(1)
                .default_value("100")
                .help("Total size of the tile bag (including 2 blanks)"),
        )
        .arg(
            Arg::new("rack-size")
                .long("rack-size")
                .env("DEFAULT_RANDOM_WORD_LETTER_COUNT")
                .num_args(1)
                .default_value("7")
                .help("Maximum word length (rack size)"),
        )
        .get_matches();


    let listen_host = matches
        .get_one::<String>("listen-host")
        .expect("listen-host argument must always have a default value")
        .clone();
    let log_file = matches.get_one::<String>("log-file");
    let share_dir = matches.get_one::<String>("share-dir").unwrap();
    let langs_str = matches.get_one::<String>("langs").unwrap();
    let total_tiles = matches
        .get_one::<String>("total-tiles")
        .unwrap()
        .parse::<usize>()
        .unwrap_or(100);
    let rack_size = matches
        .get_one::<String>("rack-size")
        .unwrap()
        .parse::<usize>()
        .unwrap_or(7);

    init_logging(log_file);

    let mut word_lists = HashMap::new();
    let mut supported_langs = Vec::new();
    let mut letter_bags = HashMap::new();
    let mut vowel_sets = HashMap::new();
    let mut consonant_sets = HashMap::new();
    let mut unicorn_sets = HashMap::new();

    for lang in langs_str.split(',') {
        let lang = lang.trim();
        info!("Loading word list for language: {} (max_len: {})", lang, rack_size);
        let words = word_loader::load_filtered_words(share_dir, lang, rack_size);
        
        // Calculate letter distribution directly from the filtered in-memory set
        let freq = distribution::calculate_distribution_from_set(&words);
        info!("Calculated letter distribution for {} ({} unique letters, from {} words)", lang, freq.len(), words.len());
        
        // Compute tile bag
        let bag = distribution::compute_tile_bag(&freq, total_tiles);
        info!("Computed tile bag for {} ({} total tiles)", lang, bag.values().sum::<usize>());
        
        // Classify letters
        let (vowels, consonants, unicorns) = letter_classifier::classify_letters(&freq, lang);
        info!("Classified letters for {}: {} vowels, {} consonants, {} unicorns", 
              lang, vowels.len(), consonants.len(), unicorns.len());
        
        // Store all pre-computed data
        word_lists.insert(lang.to_lowercase(), words);
        supported_langs.push(lang.to_lowercase());
        letter_bags.insert(lang.to_lowercase(), bag);
        vowel_sets.insert(lang.to_lowercase(), vowels);
        consonant_sets.insert(lang.to_lowercase(), consonants);
        unicorn_sets.insert(lang.to_lowercase(), unicorns);
    }

    let state = AppState {
        word_lists,
        supported_langs,
        letter_bags,
        vowel_sets,
        consonant_sets,
        unicorn_sets,
    };
    let shared_state = web::Data::new(state);

    HttpServer::new(move || {
        App::new()
            .app_data(shared_state.clone())
            .service(get_langs)
            .service(get_config)
            .service(check_word_lang)
            .service(check_word)
            .service(validate_word_lang)
            .service(validate_word)
            .service(rand_letter)
            .service(rand_vowel)
            .service(rand_consonant)
            .service(rand_unicorn)
            .service(rand_word)
    })
    .bind(&listen_host)?
    .run()
    .await
}
