mod models;
mod utils;
mod services;
mod handlers;

use actix_web::{web, App, HttpServer};
use std::collections::HashMap;
use clap::{Command, Arg};
use log::info;
use std::fs::OpenOptions;

use models::AppState;
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
            .service(handlers::config::get_langs)
            .service(handlers::config::get_config)
            .service(handlers::validation::check_word_lang)
            .service(handlers::validation::check_word)
            .service(handlers::validation::validate_word_lang)
            .service(handlers::validation::validate_word)
            .service(handlers::random::rand_letter)
            .service(handlers::random::rand_vowel)
            .service(handlers::random::rand_consonant)
            .service(handlers::random::rand_unicorn)
            .service(handlers::random::rand_word)
    })
    .bind(&listen_host)?
    .run()
    .await
}
