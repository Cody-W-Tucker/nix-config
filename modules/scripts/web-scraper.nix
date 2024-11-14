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
  content=$(curl -s "$url")

  # Extract the title and markdown content using awk
  content=$(echo "$content" | awk '
      /^Title: / { title = substr($0, 8) }
      /^Markdown Content:/ { markdown = 1; next }
      markdown { markdown_content = markdown_content $0 "\n" }
      END { print title "|" markdown_content }  # Use "|" as a delimiter 
  ')

  # Split the content into title and markdown_content using the "|" delimiter
  IFS='|' read -r title markdown_content <<< "$content"

  # Sanitize title for filename (remove characters that may cause issues: commas, brackets, spaces, etc.)
  sanitized_title=$(echo "$title" | sed 's/[^a-zA-Z0-9_-]/_/g')

  # Create the formatted content for markdown file
  formatted_content="---
  title: $title
  url: $1
  ---
  $markdown_content"

  # Generate filename using the sanitized title
  directory="$HOME/Documents/Personal"
  filename="''${directory}/''${sanitized_title}.md"

  # Check if file exists and add number if it does
  counter=1
  while [ -e "$filename" ]; do
      filename="''${directory}/''${sanitized_title}_''${counter}.md"
      ((counter++))
  done

  # Save to Obsidian vault
  echo "$formatted_content" > "$filename"
  echo "File saved as: $filename"
''
