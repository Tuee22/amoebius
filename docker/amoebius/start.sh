#!/bin/bash

# Function to check if Docker is running
docker_running() {
    docker info >/dev/null 2>&1
}

# Check if Docker socket exists (indicating DooD)
if [ -e /var/run/docker.sock ]; then
    echo "Docker socket detected. Running in DooD mode."
    
    # Wait for Docker to be ready (in case the host is still starting up)
    while ! docker_running; do
        echo "Waiting for Docker to be ready..."
        sleep 1
    done
    
    echo "Docker is ready."
else
    echo "No Docker socket detected. Running in DinD mode."
    
    # Start Docker daemon in the background
    dockerd &
    
    # Wait for Docker daemon to be ready
    while ! docker_running; do
        echo "Waiting for Docker daemon to start..."
        sleep 1
    done
    
    echo "Docker daemon is ready."
fi

# Execute the passed command or default to bash
exec "$@" || bash