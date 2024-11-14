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

# URL to fetch
url="https://r.jina.ai/$1"

# Fetch the content
content=$(curl -s "$url")

# Extract content using awk with RS and ORS settings
content_parsed=$(echo "$content" | awk '
    BEGIN { RS=""; FS="\n"; ORS="\n" }
    /^Title:/ { title=substr($0, 7) }
    /^Markdown Content:/ { 
        # Skip the "Markdown Content:" line and capture rest
        for(i=2;i<=NF;i++) { 
            if ($i ~ /^Markdown Content:/) continue
            markdown = markdown $i "\n" 
        }
    }
    END {
        print title
        print markdown
    }
')

# Read into variables using careful IFS handling
IFS=$'\n' read -r title markdown_content << EOF
$content_parsed
EOF

# Create formatted content with proper yaml frontmatter
formatted_content=$(cat << EOF
---
title: ''${title}
url: $1
date: $(date +%Y-%m-%d)
---

''${markdown_content}
EOF
)

# Generate filename
base_filename="''${title// /_}"
directory="$HOME/Documents/Personal"
filename="''${directory}/''${base_filename}.md"

# Check if file exists and add number if it does
counter=1
while [ -e "$filename" ]; do
    filename="''${directory}/''${base_filename}_''${counter}.md"
    ((counter++))
done

# Save to Obsidian vault
echo "$formatted_content" > "$filename"

echo "File saved as: $filename"
''
