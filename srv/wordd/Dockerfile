# Build stage: Compile the Rust application
FROM rust:1.72 AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy Cargo manifest and source files
COPY Cargo.toml ./
COPY src ./src

# Ensure the word list is available during build
COPY share/word.list ./share/word.list

# Generate Cargo.lock if it's missing and build the application
RUN [ -f Cargo.lock ] || cargo generate-lockfile
RUN cargo build --release

# Final stage: Create a minimal runtime image
FROM debian:buster-slim AS final

# Install necessary runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy the compiled binary from the builder stage
COPY --from=builder /app/target/release/wordd ./wordd

# Copy the word list into the runtime image
COPY --from=builder /app/share/word.list ./share/word.list

# Expose the port your app listens on
EXPOSE 8080

# Command to run the application
CMD ["./wordd", "./share/word.list"]
