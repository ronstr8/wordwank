# Build Stage
FROM rust:latest AS builder

WORKDIR /usr/src/wordd

# Copy dependency files first for efficient caching
#COPY Cargo.toml Cargo.lock ./
#RUN mkdir src && echo "fn main() {}" > src/main.rs
#RUN cargo fetch

# Copy actual source code separately to avoid unnecessary rebuilds
COPY . .

# Build the binary in release mode
RUN cargo build --release

# Runtime Stage (Debian Slim)
FROM debian:bookworm-slim

WORKDIR /app

# Copy the compiled binary
COPY --from=builder /usr/src/wordd/target/release/wordd /usr/local/bin/wordd

# Copy the share directory to /app/share
COPY --from=builder /usr/src/wordd/share /app/share

# Expose necessary ports
EXPOSE 8080

# Default command
CMD ["wordd", "--dictd-host=dictd:2628" ]
