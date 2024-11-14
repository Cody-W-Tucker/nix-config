{ config, pkgs }:

pkgs.writeShellScriptBin "web-scraper" ''
  # Check if URL is provided
  if [ $# -eq 0 ]; then
      echo "Please provide a URL as an argument."
      echo "Usage: $0 <URL>"
      exit 1
  fi

  # Validate URL input
  if ! [[ "$1" =~ ^https?:// ]]; then
      echo "Invalid URL argument. URL must start with http:// or https://"
      exit 1
  fi

  # URL to fetch (with required prefix)
  url="https://r.jina.ai/$1"

  # Fetch the content from the URL
  content=$(curl -s "$url")

  # Use awk to extract the title and markdown content while preserving newlines
  title=$(echo "$content" | awk '/^Title: / {print substr($0, 8)}')
  markdown_content=$(echo "$content" | awk '/^Markdown Content:/ {markdown=1; next} markdown {print $0}')

  # Sanitize title for filename (ensure no illegal characters in file paths)
  sanitized_title=$(echo "$title" | sed 's/[^a-zA-Z0-9_-]/_/g')

  # If the title is empty, use a fallback default title to avoid empty filename
  if [ -z "$sanitized_title" ]; then
      echo "Warning: Title could not be extracted. Using default filename."
      sanitized_title="default_filename"
  fi

  # Create well-formatted markdown content for saving to the file
  formatted_content="---
  title: $title
  url: $1
  ---
  $markdown_content"

  # Define the directory for saving the markdown files
  directory="$HOME/Documents/Personal"
  filename="''${directory}/''${sanitized_title}.md"

  # If a file with the same name already exists, append a counter to avoid overwriting
  counter=1
  while [ -e "$filename" ]; do
      filename="''${directory}/''${sanitized_title}_''${counter}.md"
      ((counter++))
  done

  # Save the formatted content to the specified filename
  echo "$formatted_content" > "$filename"
  echo "File saved as: $filename"
''
