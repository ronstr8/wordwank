FROM perl:5.38-slim

# Install system dependencies for DBD::Pg and performance modules
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libssl-dev \
    libcrypt-dev \
    pkg-config \
    build-essential \
    gcc \
    make \
    zlib1g-dev \
    && cpanm --notest App::cpanminus \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Pre-install dependencies to cache layer
COPY cpanfile .
RUN cpanm --notest --installdeps .

# Copy application code
COPY . .

# Copy application code
COPY . .

# Expose Mojolicious port
EXPOSE 3000

# Start with Hypnotoad for production performance
ENV MOJO_LISTEN="http://*:3000"
CMD ["hypnotoad", "-f", "bin/wordwank-api"]
