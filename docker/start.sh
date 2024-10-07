#!/bin/bash

# Start Docker daemon in the background
dockerd &

# Wait for Docker daemon to be ready
while (! docker stats --no-stream ); do
    echo "Waiting for Docker daemon to start..."
    sleep 1
done

# Execute the passed command or default to bash
exec "$@" || bash
