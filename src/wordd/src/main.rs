use actix_web::{get, web, App, HttpServer, HttpResponse, Responder};
use std::collections::HashSet;
use std::fs::File;
use std::io::{self, BufRead};
use std::sync::Arc;
use chrono::{Utc, SecondsFormat};

// Function to load words into a HashSet
fn load_words(file_path: &str) -> io::Result<HashSet<String>> {
    let file = File::open(file_path)?;
    let reader = io::BufReader::new(file);
    let mut words = HashSet::new();

    for line in reader.lines() {
        if let Ok(word) = line {
            words.insert(word.trim().to_string());
        }
    }
    Ok(words)
}

#[get("/word/{word}")]
async fn check_word(data: web::Data<Arc<HashSet<String>>>, word: web::Path<String>) -> impl Responder {
    let word = word.into_inner();
    let is_valid = data.contains(&word);

    let response_word = if is_valid {
        word.to_uppercase()
    } else {
        word.to_lowercase()
    };

    let status_code = if is_valid { 200 } else { 404 };

    // Log to stderr
    let timestamp = Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true);
    eprintln!("[{}] {} {}", timestamp, status_code, response_word);

    // Return the response
    HttpResponse::build(actix_web::http::StatusCode::from_u16(status_code).unwrap())
        .body(response_word)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Load the word list from the file in the share directory
    let word_list_path = "./share/word.list";
    let words = load_words(word_list_path)
        .expect("Failed to load word list");

    let shared_words = Arc::new(words);

    // Start the server
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(shared_words.clone()))
            .service(check_word)
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await
}
