# Use a base image with dictd pre-installed
FROM debian:stable-slim

# Install dictd and dictionaries (including WordNet)
RUN apt-get update && \
    apt-get install -y dictd dict-wn dict-devil dict-vera dict-gcide dict-jargon dict-foldoc curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Expose the dictd default port
EXPOSE 2628

# Copy our custom config for use within the cluster.
COPY config /etc/dictd

# Start dictd as the default command
CMD [ "sh", "-c", "dictd && sleep inf" ]
