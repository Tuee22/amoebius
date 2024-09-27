#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Calculate paths relative to the script location
BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Default paths
DEFAULT_SCRIPT_PATH="$BASE_DIR/python/scripts"
DEFAULT_MODULE_PATH="$BASE_DIR/python/amoebius"

# Default command
DEFAULT_COMMAND='["python", "/mnt/scripts/unseal_vault.py"]'

# Initialize paths with defaults
SCRIPT_PATH="$DEFAULT_SCRIPT_PATH"
MODULE_PATH="$DEFAULT_MODULE_PATH"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --command)
        CUSTOM_COMMAND="$2"
        shift # past argument
        shift # past value
        ;;
        --script-path)
        SCRIPT_PATH="$2"
        shift # past argument
        shift # past value
        ;;
        --module-path)
        MODULE_PATH="$2"
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
COMMAND=${CUSTOM_COMMAND:-$DEFAULT_COMMAND}

# Escape the command for JSON
ESCAPED_COMMAND=$(echo $COMMAND | sed 's/"/\\"/g')

# Get absolute paths
SCRIPT_ABSOLUTE_PATH=$(readlink -f "$SCRIPT_PATH")
MODULE_ABSOLUTE_PATH=$(readlink -f "$MODULE_PATH")

kubectl run script-runner --rm -i --tty --image=python:3.9 \
--overrides="{
  \"apiVersion\": \"v1\",
  \"spec\": {
    \"containers\": [
      {
        \"name\": \"script-container\",
        \"image\": \"python:3.11\",
        \"command\": $ESCAPED_COMMAND,
        \"volumeMounts\": [
          {
            \"name\": \"script-volume\",
            \"mountPath\": \"/mnt/scripts\"
          },
          {
            \"name\": \"module-volume\",
            \"mountPath\": \"/mnt/modules\"
          }
        ],
        \"env\": [
          {
            \"name\": \"PYTHONPATH\",
            \"value\": \"/mnt/modules\"
          }
        ]
      }
    ],
    \"volumes\": [
      {
        \"name\": \"script-volume\",
        \"hostPath\": {
          \"path\": \"$SCRIPT_ABSOLUTE_PATH\",
          \"type\": \"Directory\"
        }
      },
      {
        \"name\": \"module-volume\",
        \"hostPath\": {
          \"path\": \"$MODULE_ABSOLUTE_PATH\",
          \"type\": \"Directory\"
        }
      }
    ]
  }
}"