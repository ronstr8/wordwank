use actix_web::{get, web, App, HttpServer, HttpResponse, Responder};

use std::collections::{HashSet};

use std::fs::File;

use std::io::{self, BufRead, BufReader, Write};

use std::sync::{Arc};

use std::net::TcpStream;

use clap::{Command, Arg};

use log::{error, info};

use env_logger;



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



fn load_filtered_words(valid_path: &str, censored_path: &str) -> HashSet<String> {

    let valid_words = load_words(valid_path).expect("Failed to load valid word list. Exiting.");

    let censored_words = load_words(censored_path).unwrap_or_default();

    

    valid_words.difference(&censored_words).cloned().collect()

}



fn query_dictd(host: &str, word: &str) -> io::Result<String> {

    let mut stream = TcpStream::connect(host)?;

    let command = format!("DEFINE * {}\n", word);

    stream.write_all(command.as_bytes())?;

    

    let reader = BufReader::new(stream);

    let mut response = String::new();

    for line in reader.lines() {

        let line = line?;

        if line.starts_with("250") { // End of definition marker

            break;

        }

        response.push_str(&line);

        response.push('\n');

    }

    Ok(response)

}



#[get("/word/{word}")]

async fn check_word(

    data: web::Data<Arc<HashSet<String>>>,

    dictd_host: web::Data<Option<String>>,

    word: web::Path<String>,

) -> impl Responder {

    let word = word.into_inner();

    let is_valid = data.contains(&word.to_uppercase());

    

    if !is_valid {

        info!("Invalid word queried: {}", word.to_lowercase());

        return HttpResponse::NotFound().finish();

    }

    

    if let Some(host) = dictd_host.get_ref() {

        match query_dictd(&host, &word) {

            Ok(response) => {

                info!("Valid word queried: {}", word.to_uppercase());

                HttpResponse::Ok().body(response)

            },

            Err(_) => {

                error!("Failed to query dictd for word: {}", word.to_uppercase());

                HttpResponse::NotFound().finish()

            }

        }

    } else {

        info!("Valid word without dictd lookup: {}", word.to_uppercase());

        HttpResponse::Ok().finish()

    }

}



#[actix_web::main]

async fn main() -> std::io::Result<()> {

    env_logger::init();

    

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

        .arg(

            Arg::new("listen-host")

                .long("listen-host")

                .num_args(1)

                .default_value("127.0.0.1:8080")

                .help("Specify the listen address (e.g., 0.0.0.0:2345)"),

        )

        .get_matches();



    let dictd_host = matches.get_one::<String>("dictd-host").cloned();

    let listen_host = matches.get_one::<String>("listen-host").unwrap().clone();

    

    let words = load_filtered_words("./share/valid-words.txt", "./share/censored-words.txt");

    let shared_words = Arc::new(words);



    HttpServer::new(move || {

        App::new()

            .app_data(web::Data::new(shared_words.clone()))

            .app_data(web::Data::new(dictd_host.clone()))

            .service(check_word)

    })

    .bind(&listen_host)?

    .run()

    .await

}
