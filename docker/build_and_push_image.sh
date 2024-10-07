#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Variables - replace these with your own Docker Hub username and image name
DOCKER_USERNAME="tuee22"
DOCKER_IMAGE="amoebius"
IMAGE_TAG="0.0.1"

# Login to Docker Hub (ensure you have Docker credentials set up)
echo "Logging into Docker Hub..."
docker login || { echo "Docker login failed"; exit 1; }

# Build the Docker image
echo "Building Docker image..."
docker build \
  -t "$DOCKER_USERNAME/$DOCKER_IMAGE:$IMAGE_TAG" \
  -t "$DOCKER_USERNAME/$DOCKER_IMAGE:latest" \
  -f ./Dockerfile \
  ../

# Push the Docker image
echo "Pushing Docker image..."
docker push "$DOCKER_USERNAME/$DOCKER_IMAGE:$IMAGE_TAG"
docker push "$DOCKER_USERNAME/$DOCKER_IMAGE:latest"

echo "Done!"