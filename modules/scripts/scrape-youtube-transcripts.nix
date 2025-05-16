{ pkgs }:

pkgs.writeShellScriptBin "scrape-youtube-transcripts" ''
#!/usr/bin/env bash

set -euo pipefail

if [ -z "''${1:-}" ]; then
  echo "Usage: $0 <YOUTUBE_VIDEO_OR_PLAYLIST_URL>"
  exit 1
fi

URL="$1"
OUTDIR="transcripts_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

# Get metadata for all videos
mapfile -t meta_lines < <(
  yt-dlp --skip-download --write-subs --write-auto-subs \
    --sub-lang en --sub-format ttml --convert-subs srt \
    --output "$OUTDIR/%(id)s.%(ext)s" \
    --print "%(id)s|||%(title)s|||%(uploader)s|||%(upload_date)s" \
    "$URL"
)

for meta in "''${meta_lines[@]}"; do
  IFS='|||' read -r video_id title channel upload_date <<< "$meta"
  srt="$OUTDIR/$video_id.en.srt"
  [ -e "$srt" ] || continue

  # Format date as YYYY-MM-DD if available
  if [[ "$upload_date" =~ ^[0-9]{8}$ ]]; then
    upload_date="''${upload_date:0:4}-''${upload_date:4:2}-''${upload_date:6:2}"
  else
    upload_date=""
  fi

  # Sanitize title for filename
  safe_title=$(echo "$title" | tr '/:*?"<>|' '_' | sed 's/  */ /g' | tr -d "'")
  filename="''${safe_title} [''${video_id}]"

  # Clean and flatten transcript
  transcript=$(sed -e '/^[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9] --> [0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]$/d' \
      -e '/^[[:digit:]]\{1,3\}$/d' \
      -e 's/<[^>]*>//g' \
      -e '/^[[:space:]]*$/d' \
      "$srt" | tr '\n' ' ' | sed 's/  */ /g')

  # Write YAML frontmatter and transcript to file
  {
    echo "---"
    echo "title: \"$title\""
    echo "video_id: \"$video_id\""
    echo "url: \"https://www.youtube.com/watch?v=$video_id\""
    echo "channel: \"$channel\""
    if [ -n "$upload_date" ]; then
      echo "date: \"$upload_date\""
    fi
    echo "---"
    echo "$transcript"
  } > "$OUTDIR/$filename.md"

  rm "$srt"
done

echo "All transcripts saved in $OUTDIR/ as TITLE [VIDEO_ID].txt with YAML frontmatter"

''