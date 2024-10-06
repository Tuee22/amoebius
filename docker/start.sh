#!/bin/bash

# Start the Docker daemon in the background
dockerd &

# Wait for Docker to start (optional, but good for stability)
while(! docker info > /dev/null 2>&1); do
    echo "Waiting for Docker to start..."
    sleep 1
done

# Execute the passed command (CMD or arguments)
exec "$@"
