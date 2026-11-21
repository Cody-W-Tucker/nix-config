# mdBook preprocessor (see book.toml). mdBook runs it from docs/.
#
# Pages link to repository files relatively (../../modules/...), which works when browsing on
# GitHub. On the published site those paths do not exist, so this rewrites them to GitHub URLs.
# It also fails the build when a relative link points at a file that is not there.
set -euo pipefail

# mdBook asks whether each renderer is supported; this works for all of them.
[ "${1:-}" = supports ] && exit 0

repo_url="https://github.com/Cody-W-Tucker/nix-config/blob/main"

dead=0
while IFS= read -r hit; do
  page=${hit%%:*}
  target=${hit#*:](}
  target=${target%%#*}
  case "$target" in
    http://* | https://* | mailto:* | "") continue ;;
    ../../*) path="../${target#../../}" ;;
    *) path="src/$target" ;;
  esac
  if [ ! -e "$path" ]; then
    printf 'source-links: %s links to missing %s\n' "$page" "$target" >&2
    dead=1
  fi
done < <(grep -oE '\]\([^) ]+' src/*.md)
[ "$dead" -eq 0 ] || exit 1

jq --arg url "$repo_url/" '.[1] | walk(
  if type == "object" and (.content | type) == "string"
  then .content |= gsub("\\]\\(\\.\\./\\.\\./"; "](" + $url)
  else . end)'
