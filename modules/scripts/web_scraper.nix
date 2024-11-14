{ pkgs }:

pkgs.writeShellScriptBin "web-scraper" ''

# Check if URL is provided
if [ $# -eq 0 ]; then
    echo "Please provide a URL as an argument."
    echo "Usage: $0 <URL>"
    exit 1
fi

# Validate URL input
if ! [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Invalid URL argument."
    exit 1
fi

# URL to fetch
url="https://r.jina.ai/$1"

# Fetch the content
content=$(curl -s "$url")

# Extract the title, URL, and markdown content using awk
read -r title source_url markdown_content <<EOF
$(echo "$content" | awk '
    /^Title: / { title = substr($0, 8) }
    /^URL Source: / { source_url = substr($0, 12) }
    /^Markdown Content:/ { markdown = 1; next }
    markdown { markdown_content = markdown_content $0 "\n" }
    END { print title, source_url, markdown_content }
')
EOF

# Create the formatted content
formatted_content="---
title: $title
url: $source_url
---

$markdown_content"

# Generate filename
base_filename="${title// /_}"
filename="/Documents/Personal/${base_filename}.md"

# Check if file exists and add number if it does
counter=1
while [ -e "$filename" ]; do
    filename="/Documents/Personal/${base_filename}_${counter}.md"
    ((counter++))
done

# Save to Obsidian vault
echo "$formatted_content" > "$filename"

echo "File saved as: $filename"
''
