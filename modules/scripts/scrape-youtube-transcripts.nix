{ pkgs }:

pkgs.writeShellScriptBin "scrape-youtube-transcripts" ''
#!/usr/bin/env bash
set -euo pipefail

if [ -z "''${1:-}" ]; then
  echo "Usage: $0 <YOUTUBE_VIDEO_OR_PLAYLIST_URL>"
  exit 1
fi

URL="$1"
OUTDIR="transcripts"
mkdir -p "$OUTDIR"

# Get video IDs from the playlist or single video
mapfile -t video_ids < <(yt-dlp --flat-playlist --get-id "$URL")

for video_id in "''${video_ids[@]}"; do
  # Download subtitles and print metadata in one call, with sleep between videos
  meta_line=$(yt-dlp \
    --skip-download \
    --write-subs --write-auto-subs --sub-lang en --convert-subs srt \
    --sleep-interval 2 --max-sleep-interval 5 \
    --output "$OUTDIR/$video_id.%(ext)s" \
    --print "%(title)s|||%(uploader)s|||%(upload_date)s" \
    "https://www.youtube.com/watch?v=$video_id"
  )

  # Find the SRT file (could be .en.srt or just .srt)
  srt=$(find "$OUTDIR" -type f -name "$video_id*.srt" | head -n1)
  [ -e "$srt" ] || { echo "No SRT for $video_id"; continue; }

  # Parse metadata
  IFS='|||' read -r title channel upload_date <<< "$meta_line"

  # Format date as YYYY-MM-DD if available
  if [[ "$upload_date" =~ ^[0-9]{8}$ ]]; then
    upload_date="''${upload_date:0:4}-''${upload_date:4:2}-''${upload_date:6:2}"
  else
    upload_date=""
  fi

  # Sanitize title for filename
  safe_title=$(echo "$title" | tr '/:*?"<>|' '_' | sed 's/  */ /g' | tr -d "'")
  [ -n "$safe_title" ] || safe_title="untitled"
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

echo "All transcripts saved in $OUTDIR/ as TITLE [VIDEO_ID].md"
''
