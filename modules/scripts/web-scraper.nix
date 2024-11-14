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

  # URL to fetch from (ensure to use the correct base URL structure here)
  url="https://r.jina.ai/$1"

  # Fetch the content
  content=$(curl -s "$url")

  # Debugging: Display the fetched content.
  echo "Fetched content:"
  echo "$content"

  # Extract the title and markdown content using awk, ensuring multi-line content handling
  content=$(echo "$content" | awk '
      BEGIN { title=""; markdown_content=""; markdown=0 }
      /^Title: / { title = substr($0, 8); next }  # Extract title
      /^Markdown Content:/ { markdown = 1; next }  # Begin capturing markdown content
      markdown { markdown_content = markdown_content $0 "\n" }  # Accumulate markdown content preserving newlines
      END { print title "|" markdown_content }
  ')

  # Confirm extracted content for debugging
  echo "Extracted content (title and markdown):"
  echo "$content"

  # Split the content into title and markdown_content using the "|" delimiter
  IFS='|' read -r title markdown_content <<< "$content"

  # Check extracted values for title and markdown content
  echo "Parsed title: $title"
  echo "Parsed markdown content:"
  echo "$markdown_content"

  # Sanitize title for filename (only include valid characters for filenames)
  sanitized_title=$(echo "$title" | sed 's/[^a-zA-Z0-9_-]/_/g')

  # Debug: Check sanitized title
  echo "Sanitized title: $sanitized_title"

  # If title is still empty after sanitization, provide a default filename
  if [ -z "$sanitized_title" ]; then
      echo "Warning: Title could not be extracted. Using default filename."
      sanitized_title="default_filename"
  fi

  # Format the content for markdown saving
  formatted_content="---
  title: $title
  url: $1
  ---
  $markdown_content"

  # Debugging: Check formatted_content
  echo "Formatted Content:"
  echo "$formatted_content"

  # Generate filename using sanitized title
  directory="$HOME/Documents/Personal"
  filename="''${directory}/''${sanitized_title}.md"

  # If a file with the same filename exists, add a counter to the filename
  counter=1
  while [ -e "$filename" ]; do
      filename="''${directory}/''${sanitized_title}_''${counter}.md"
      ((counter++))
  done

  # Save the content to the file
  echo "$formatted_content" > "$filename"
  echo "File saved as: $filename"
''
