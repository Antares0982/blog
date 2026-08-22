#!/usr/bin/env bash
# Live preview with hugo's rebuild-on-save server.
#
#   ./dev.sh            # terminal, the default theme
#   ./dev.sh diary      # the other one
#
# The Nix build stages the themes, the self-hosted KaTeX / Material Icons
# assets and this repo's overlay/ for the chosen theme, none of which are in
# git. This drops the same tree into the working directory (gitignored) and
# hands off to `hugo server`.
set -euo pipefail
cd "$(dirname "$0")"

theme="${1:-terminal}"
case "$theme" in
  terminal|diary) shift || true ;;
  -*) theme="terminal" ;;
  *) echo "unknown theme: $theme (expected terminal or diary)" >&2; exit 1 ;;
esac

vendor="$(nix build --no-link --print-out-paths .#vendor)"

rm -rf themes static/vendor
mkdir -p static
cp -r "$vendor/themes" .
cp -r "$vendor/static/vendor" static/
chmod -R u+w themes static/vendor
cp -r "overlay/$theme" "themes/$theme-overlay"

exec nix run nixpkgs#hugo -- server --environment "$theme" \
  --buildDrafts --disableFastRender "$@"
