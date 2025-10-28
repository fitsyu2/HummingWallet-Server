FROM swift:5.9-focal

WORKDIR /app

# Copy package files first for better caching
COPY Package.swift Package.resolved ./

# Resolve dependencies first
RUN swift package resolve

# Copy source code
COPY Sources ./Sources

# Build the project in release mode for faster startup
RUN swift build -c release

# Railway dynamically assigns the PORT environment variable
# Server will bind to 0.0.0.0:$PORT

# Run the release version for better performance
CMD ["swift", "run", "-c", "release"]