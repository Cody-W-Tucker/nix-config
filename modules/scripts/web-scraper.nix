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

  # URL to fetch (make sure the URL structure is correct here)
  url="$1"

  # Fetch the content
  content=$(curl -s "https://r.jina.ai/$url")

  # Display the fetched content for debugging
  echo "Fetched content:"
  echo "$content"

  # Extract the title and markdown content using awk
  content=$(echo "$content" | awk '
      BEGIN { title=""; markdown_content="" }
      /^Title: / { title = substr($0, 8); next }  # Extract title
      /^Markdown Content:/ { markdown = 1; next }  # Begin extracting markdown content from here
      markdown { markdown_content = markdown_content $0 "\n" }
      END { print title "|" markdown_content }  # Use the "|" delimiter
  ')

  # Display the extracted content for debugging
  echo "Extracted content (title and markdown):"
  echo "$content"

  # Split the content into title and markdown_content using the "|" delimiter
  IFS='|' read -r title markdown_content <<< "$content"

  # Debugging: Check if the title and markdown_content were correctly parsed
  echo "Parsed title: $title"
  echo "Parsed markdown content:"
  echo "$markdown_content"

  # Sanitize title for filename (remove characters that may cause issues: spaces, commas, brackets)
  sanitized_title=$(echo "$title" | sed 's/[^a-zA-Z0-9_-]/_/g')

  # Debugging: Check sanitized title
  echo "Sanitized title: $sanitized_title"

  # If title is still empty after sanitization, provide a default filename
  if [ -z "$sanitized_title" ]; then
      echo "Warning: Title could not be extracted. Using default filename."
      sanitized_title="default_filename"
  fi

  # Create the formatted content for markdown file
  formatted_content="---
  title: $title
  url: $1
  ---
  $markdown_content"

  # Generate filename using the sanitized title
  directory="$HOME/Documents/Personal"
  filename="''${directory}/''${sanitized_title}.md"

  # Check if file exists and add a number to the filename if it does
  counter=1
  while [ -e "$filename" ]; do
      filename="''${directory}/''${sanitized_title}_''${counter}.md"
      ((counter++))
  done

  # Save to Obsidian vault
  echo "$formatted_content" > "$filename"
  echo "File saved as: $filename"
''
