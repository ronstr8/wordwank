# Use a base image with dictd pre-installed
FROM debian:stable-slim

# Install dictd and dictionaries (including WordNet)
RUN apt-get update && \
    apt-get install -y dictd dict-wn dict-devil dict-vera dict-gcide dict-jargon dict-foldoc && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Expose the dictd default port
EXPOSE 2628

# Add dictionaries (if additional dictionaries are needed, copy them here)
# For example:
# ADD your-dictionary-files /usr/share/dictd/

# Configure dictd to use the dictionaries
RUN mkdir -p /etc/dictd && \
    echo "database \
        /usr/share/dictd/wn \"WordNet\"\n\
        /usr/share/dictd/devil \"Devil's Dictionary\"\n\
        /usr/share/dictd/vera \"V.E.R.A.\"\n\
        /usr/share/dictd/gcide \"GNU Collaborative International Dictionary of English\"\n\
        /usr/share/dictd/jargon \"Jargon File\"\n\
        /usr/share/dictd/foldoc \"Free On-line Dictionary of Computing\"\n" > /etc/dictd/dictd.conf

# Start dictd as the default command
CMD ["dictd", "-d"]
