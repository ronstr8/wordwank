use actix_web::{get, web, App, HttpServer, HttpResponse, Responder};
use std::collections::{HashSet, HashMap};
use std::fs::File;
use std::io::{self, BufRead, Write, BufReader};
use std::net::TcpStream;
use std::sync::{Arc, Mutex};
use chrono::{Utc, SecondsFormat};
use clap::{App as ClapApp, Arg};

// Function to load words from a file into a HashSet
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

// Function to load the valid word list and remove censored words
fn load_filtered_words(valid_path: &str, censored_path: &str) -> HashSet<String> {
    let valid_words = load_words(valid_path).expect("Failed to load valid word list. Exiting.");
    let censored_words = load_words(censored_path).unwrap_or_default();

    valid_words.into_iter().filter(|word| !censored_words.contains(word)).collect()
}

// Function to query dictd server for a word definition
fn query_dictd(host: &str, word: &str, cache: &Mutex<HashMap<String, String>>) -> Option<String> {
    let mut cache_lock = cache.lock().unwrap();

    // Check if the word is already in the cache
    if let Some(cached_response) = cache_lock.get(word) {
        return Some(cached_response.clone());
    }

    if let Ok(mut stream) = TcpStream::connect(host) {
        let command = format!("DEFINE * {}\n", word);
        if stream.write_all(command.as_bytes()).is_ok() {
            let reader = BufReader::new(stream);
            let mut response = String::new();

            for line in reader.lines() {
                if let Ok(content) = line {
                    if content.starts_with("250") { // End of definition marker
                        break;
                    }
                    response.push_str(&content);
                    response.push('\n');
                } else {
                    break;
                }
            }

            // Cache the response
            cache_lock.insert(word.to_string(), response.clone());
            return Some(response);
        }
    }
    None
}

#[get("/word/{word}")]
async fn check_word(
    data: web::Data<Arc<HashSet<String>>>,
    dictd_host: web::Data<Option<String>>,
    cache: web::Data<Mutex<HashMap<String, String>>>,
    word: web::Path<String>,
) -> impl Responder {
    let word = word.into_inner().to_uppercase();
    let is_valid = data.contains(&word);

    // Query dictd for additional information
    let dictd_response = if let Some(host) = dictd_host.get_ref() {
        query_dictd(host, &word, &cache)
    } else {
        None
    };

    let status_code = if is_valid { 200 } else { 404 };

    // Construct the response body
    let response_body = match dictd_response {
        Some(dict_data) => format!("{{\"word\": \"{}\", \"valid\": {}, \"dictd\": \"{}\"}}", word, is_valid, dict_data.replace('"', "\\\"")),
        None => format!("{{\"word\": \"{}\", \"valid\": {}, \"dictd\": null}}", word, is_valid),
    };

    // Log to stderr
    let timestamp = Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true);
    eprintln!("[{}] {} {}", timestamp, status_code, response_body);

    // Return the response
    HttpResponse::build(actix_web::http::StatusCode::from_u16(status_code).unwrap())
        .content_type("application/json")
        .body(response_body)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Parse command-line arguments
    let matches = ClapApp::new("wordd")
        .version("1.1")
        .author("Your Name <you@example.com>")
        .about("Word validity and lookup service")
        .arg(
            Arg::new("dictd-host")
                .long("dictd-host")
                .takes_value(true)
                .about("Specify the dictd host (e.g., localhost:2628)"),
        )
        .get_matches();

    let dictd_host = matches.value_of("dictd-host").map(String::from);

    // Load valid and censored word lists
    let valid_words_path = "./share/valid-words.txt";
    let censored_words_path = "./share/censored-words.txt";
    let words = load_filtered_words(valid_words_path, censored_words_path);

    let shared_words = Arc::new(words);
    let cache = web::Data::new(Mutex::new(HashMap::new()));

    // Start the server
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(shared_words.clone()))
            .app_data(web::Data::new(dictd_host.clone()))
            .app_data(cache.clone())
            .service(check_word)
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await
}
