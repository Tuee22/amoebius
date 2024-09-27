#!/bin/bash

# Enable debug mode
set -x

# Function to clean up resources
cleanup() {
    echo "Cleaning up..."
    kubectl delete pod script-runner --grace-period=0 --force --ignore-not-found
}

# Set up trap to ensure cleanup on exit
trap cleanup EXIT

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "Script directory: $SCRIPT_DIR"

# Calculate the base directory (amoebius directory)
AMOEBIUS_DIR="$( dirname "$SCRIPT_DIR" )"
echo "Amoebius directory: $AMOEBIUS_DIR"

# Path for Amoebius directory in the container (this should match the Terraform config)
CONTAINER_AMOEBIUS_PATH="/amoebius"

# Default command
DEFAULT_COMMAND='["python", "/amoebius/python/scripts/unseal_vault.py"]'

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --command)
        CUSTOM_COMMAND="$2"
        shift # past argument
        shift # past value
        ;;
        *)
        # Unknown option
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Use custom command if provided, otherwise use default
if [ -n "$CUSTOM_COMMAND" ]; then
    # Remove surrounding square brackets if present
    CUSTOM_COMMAND="${CUSTOM_COMMAND#[}"
    CUSTOM_COMMAND="${CUSTOM_COMMAND%]}"
    
    # Split the command into an array
    IFS=',' read -ra CMD_ARRAY <<< "$CUSTOM_COMMAND"
    
    # Build the JSON array
    COMMAND="["
    for i in "${CMD_ARRAY[@]}"; do
        # Trim leading/trailing whitespace and quotes
        i="${i#"${i%%[![:space:]]*}"}"
        i="${i%"${i##*[![:space:]]}"}"
        i="${i#\"}"
        i="${i%\"}"
        COMMAND+="\"$i\","
    done
    COMMAND="${COMMAND%,}]"
else
    COMMAND="$DEFAULT_COMMAND"
fi

echo "Command to be executed: $COMMAND"

# Run the pod with the command
echo "Creating pod..."
kubectl run script-runner --image=python:3.11 --restart=Never \
--overrides="{
  \"apiVersion\": \"v1\",
  \"spec\": {
    \"containers\": [
      {
        \"name\": \"script-container\",
        \"image\": \"python:3.11\",
        \"command\": [\"tail\", \"-f\", \"/dev/null\"],
        \"volumeMounts\": [
          {
            \"name\": \"amoebius-volume\",
            \"mountPath\": \"$CONTAINER_AMOEBIUS_PATH\"
          }
        ],
        \"env\": [
          {
            \"name\": \"PYTHONPATH\",
            \"value\": \"$CONTAINER_AMOEBIUS_PATH:$CONTAINER_AMOEBIUS_PATH/python\"
          }
        ]
      }
    ],
    \"volumes\": [
      {
        \"name\": \"amoebius-volume\",
        \"hostPath\": {
          \"path\": \"$CONTAINER_AMOEBIUS_PATH\",
          \"type\": \"Directory\"
        }
      }
    ],
    \"nodeSelector\": {
      \"kubernetes.io/hostname\": \"kind-cluster-control-plane\"
    }
  }
}"

# Wait for the pod to be ready
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod/script-runner --timeout=60s

# Attach to the pod and run the command
echo "Attaching to pod..."
kubectl exec -it script-runner -- ${CMD_ARRAY[@]:-/bin/bash}

# Cleanup is handled by the trap, so we don't need to call it explicitly here

# Disable debug mode
set +x