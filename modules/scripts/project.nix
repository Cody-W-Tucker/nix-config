{ pkgs }:

pkgs.writeShellScriptBin "project" ''
  set -e

  TEMPLATE_BASE="https://flakehub.com/f/Cody-W-Tucker/dev-templates/*"

  show_help() {
    echo "Usage: project <command> <template> [directory]"
    echo ""
    echo "Commands:"
    echo "  init <template>     Initialize a flake template in the current directory"
    echo "  new <template> <dir>  Create a new project with the specified template"
    echo ""
    echo "Available templates:"
    echo "  bun, empty, go, jupyter, node, nix, protobuf"
    echo "  python, ruby, ruby-on-rails, rust, shell"
    echo "  swi-prolog, zig"
  }

  if [ $# -lt 1 ]; then
    show_help
    exit 1
  fi

  COMMAND="$1"

  case "$COMMAND" in
    init)
      if [ $# -lt 2 ]; then
        echo "Error: Template name required"
        show_help
        exit 1
      fi
      TEMPLATE="$2"
      echo "Initializing $TEMPLATE template in current directory..."
      nix flake init --template "''${TEMPLATE_BASE}#$TEMPLATE"
      echo "Initialized $TEMPLATE project!"
      echo "Run: direnv allow"
      ;;
    new)
      if [ $# -lt 3 ]; then
        echo "Error: Template name and directory required"
        show_help
        exit 1
      fi
      TEMPLATE="$2"
      DIRECTORY="$3"
      echo "Creating new $TEMPLATE project in $DIRECTORY..."
      nix flake new --template "''${TEMPLATE_BASE}#$TEMPLATE" "$DIRECTORY"
      echo "Created $TEMPLATE project in $DIRECTORY"
      echo "Run: cd $DIRECTORY && direnv allow"
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      echo "Unknown command: $COMMAND"
      show_help
      exit 1
      ;;
  esac
''
