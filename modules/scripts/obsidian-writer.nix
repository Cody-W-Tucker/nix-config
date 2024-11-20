{ pkgs }:

pkgs.writeShellScriptBin "obsidian-to-file" ''
  #!/bin/bash

  # Set the Obsidian directory path
  OBSIDIAN_DIR="$HOME/Obsidian"

  # Create a filename with the current date and time
  FILENAME="terminal_output_$(date +%Y%m%d_%H%M%S).txt"

  # Full path for the output file
  OUTPUT_FILE="$OBSIDIAN_DIR/$FILENAME"

  # Read from stdin and write to the output file
  cat > "$OUTPUT_FILE"

  echo "Terminal output has been saved to $OUTPUT_FILE"
''
