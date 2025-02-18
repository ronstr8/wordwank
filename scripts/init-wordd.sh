#!/bin/bash

BASE_DIR="srv/wordd"

# Create necessary directories
mkdir -p $BASE_DIR/{src,helm/templates,share}

# Create Cargo.toml
cat << 'EOF' > $BASE_DIR/Cargo.toml
[package]
name = "wordd"
version = "1.1.0"
edition = "2021"
authors = ["Ron Straight <straightre@gmail.com>"]
description = "Word validity and lookup service for Wordwank"
license = "MIT"

[dependencies]
actix-web = "4"
chrono = "0.4"
clap = { version = "4.3", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"

[profile.release]
opt-level = 3
EOF

# Create Dockerfile
cat << 'EOF' > $BASE_DIR/Dockerfile
FROM rust:1.75 as builder

WORKDIR /usr/src/wordd

COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release && rm -rf src

COPY . .
RUN cargo build --release

FROM debian:bullseye-slim

WORKDIR /app
COPY --from=builder /usr/src/wordd/target/release/wordd /usr/local/bin/wordd

EXPOSE 8080

CMD ["wordd"]
EOF

# Create Helm Chart
mkdir -p $BASE_DIR/helm/templates

cat << 'EOF' > $BASE_DIR/helm/Chart.yaml
apiVersion: v2
name: wordd
description: A Rust-based microservice for Wordwank word validation
type: application
version: 0.1.0
EOF

cat << 'EOF' > $BASE_DIR/helm/values.yaml
replicaCount: 1

image:
  repository: ghcr.io/ronstr8/wordd
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

resources: {}
EOF

cat << 'EOF' > $BASE_DIR/helm/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordd
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: wordd
  template:
    metadata:
      labels:
        app: wordd
    spec:
      containers:
      - name: wordd
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.service.port }}
        env:
        - name: DICTD_HOST
          value: "localhost:2628"
EOF

cat << 'EOF' > $BASE_DIR/helm/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: wordd
spec:
  type: {{ .Values.service.type }}
  selector:
    app: wordd
  ports:
    - protocol: TCP
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
EOF

# Create src/main.rs
cat << 'EOF' > $BASE_DIR/src/main.rs
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
EOF

echo "Wordd service setup completed in $BASE_DIR"
