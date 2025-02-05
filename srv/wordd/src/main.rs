use actix_web::{get, web, App, HttpServer, HttpResponse, Responder};
use std::collections::{HashSet, HashMap};
use std::fs::File;
use std::io::{self, BufRead, Write, BufReader};
use std::net::TcpStream;
use std::sync::{Arc, Mutex};
use chrono::{Utc, SecondsFormat};
use clap::{Command, Arg};

fn load_words(file_path: &str) -> io::Result<HashSet<String>> {
    let file = File::open(file_path)?;
    let reader = io::BufReader::new(file);
    let mut words = HashSet::new();

    for line in reader.lines() {
        if let Ok(word) = line {
            words.insert(word.trim().to_uppercase());
        }
    }
    Ok(words)
}

fn load_filtered_words(valid_path: &str, censored_path: &str) -> HashSet<String> {
    let valid_words = load_words(valid_path).expect("Failed to load valid word list. Exiting.");
    let censored_words = load_words(censored_path).unwrap_or_default();

    valid_words.into_iter().filter(|word| !censored_words.contains(word)).collect()
}

#[get("/word/{word}")]
async fn check_word(
    data: web::Data<Arc<HashSet<String>>>,
    word: web::Path<String>,
) -> impl Responder {
    let word = word.into_inner().to_uppercase();
    let is_valid = data.contains(&word);
    let status_code = if is_valid { 200 } else { 404 };

    HttpResponse::build(actix_web::http::StatusCode::from_u16(status_code).unwrap())
        .content_type("application/json")
        .body(format!("{{\"word\": \"{}\", \"valid\": {}}}", word, is_valid))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let matches = Command::new("wordd")
        .version("1.1")
        .author("Ron Straight <straightre@gmail.com>")
        .about("Word validity and lookup service")
        .arg(
            Arg::new("dictd-host")
                .long("dictd-host")
                .num_args(1)
                .help("Specify the dictd host (e.g., localhost:2628)"),
        )
        .get_matches();

    let dictd_host = matches.get_one::<String>("dictd-host").cloned();
    let words = load_filtered_words("./share/valid-words.txt", "./share/censored-words.txt");

    let shared_words = Arc::new(words);

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(shared_words.clone()))
            .service(check_word)
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await
}
