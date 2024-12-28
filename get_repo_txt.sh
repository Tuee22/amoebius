#!/bin/bash

# Name of the output file
OUTPUT_FILE="repo.txt"

# Check if the script is run inside a Git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: This script must be run inside a Git repository."
    exit 1
fi

# Get the list of tracked files
tracked_files=$(git ls-files)

# Check if any tracked files exist
if [ -z "$tracked_files" ]; then
    echo "No tracked files found."
    exit 0
fi

# Create or overwrite the output file
> "$OUTPUT_FILE"

# Loop through each tracked file and append its contents to the output file
for file in $tracked_files; do
    # Exclude .png, .dockerignore, .gitignore, LICENSE, and README.md files
    if [[ $file == *.png || $file == ".dockerignore" || $file == ".gitignore" || $file == "LICENSE" || $file == "README.md" ]]; then
        echo "Skipping: $file (excluded file)"
        continue
    fi

    if [ -f "$file" ]; then
        echo "Processing: $file"
        # Add the filename as a header
        echo "=== $file ===" >> "$OUTPUT_FILE"
        # Append the file's content
        cat "$file" >> "$OUTPUT_FILE"
        # Add a newline for separation
        echo -e "\n" >> "$OUTPUT_FILE"
    else
        echo "Skipping: $file (not a regular file)"
    fi
done

echo "All tracked files concatenated into $OUTPUT_FILE"
