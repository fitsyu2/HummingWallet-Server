FROM swift:5.9-focal

WORKDIR /app

# Copy package files
COPY Package.swift Package.resolved ./

# Copy source code
COPY Sources ./Sources

# Build the project
RUN swift build -c release

# Expose port
EXPOSE 10000

# Run the server
CMD ["swift", "run", "-c", "release"]