FROM rust:1.75 AS builder

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
