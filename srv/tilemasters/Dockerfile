# Use the official Raku image as the base
FROM rakudo-star:latest

# Set the working directory inside the container
WORKDIR /tilemasters

# Copy the project files into the container
COPY . .

# Install dependencies from META6.json (if any exist)
RUN test -f META6.json && zef install --depsonly . || echo "No dependencies to install"

# Run tests from the t/ directory
RUN prove6 -ve 'raku' t/

# Set the default command
CMD ["raku", "-Ilib", "bin/tilemasters.raku"]
