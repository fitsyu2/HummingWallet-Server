FROM swift:5.9-focal

WORKDIR /app

# Copy package files
COPY Package.swift Package.resolved ./

# Copy source code
COPY Sources ./Sources

# Build the project
RUN swift build -c release

# Render dynamically assigns the PORT environment variable
# No need to hardcode EXPOSE - Render handles this

# Run the server
CMD ["swift", "run", "-c", "release"]