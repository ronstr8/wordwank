FROM ollama/ollama:latest

# Set the host to 0.0.0.0
ENV OLLAMA_HOST=0.0.0.0

# We need to start the server to pull the model during build time
# The models are stored in /root/.ollama
RUN (ollama serve &) && \
    sleep 10 && \
    ollama pull phi3:mini && \
    pkill ollama

# Ensure the model directory exists and has correct permissions 
# (though as root in official image it should be fine)
RUN ls -la /root/.ollama

EXPOSE 11434

ENTRYPOINT ["ollama", "serve"]
