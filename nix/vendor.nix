# Both themes, plus local copies of everything they would otherwise pull from a
# CDN. Terminal self-hosts its fonts and needs only KaTeX, which it ships no
# support for at all; diary wants KaTeX from jsdelivr and Material Icons from
# fonts.googleapis.com, both render-blocking and both slow to dead from
# mainland China.
#
# Both are vendored unconditionally. They come to ~5 MB together, the fetch is
# cached, and a theme-conditional derivation would mean two store paths and a
# rebuild every time the switch is flipped.
#
# Split out of site.nix so ./dev.sh can drop the same tree into the working
# directory and run `hugo server` against it.
{
  lib,
  stdenvNoCC,
  fetchurl,
  katex,
  terminal,
  diary,
}:

let
  katexDist = "${katex}/lib/node_modules/katex/dist";

  # nixpkgs' material-icons (4.0.0) predates the dark_mode/light_mode glyphs
  # diary's theme-toggle uses, so take the font from Google's CDN. The gstatic
  # URL is version-pinned and immutable, and it is fetched at build time only --
  # readers never talk to Google.
  materialIcons = fetchurl {
    url = "https://fonts.gstatic.com/s/materialicons/v145/flUhRq6tzZclQEJ-Vdg-IuiaDsNc.woff2";
    hash = "sha256-gmX2R4Y5fWuDLRygqv3xSa2E5ydZ//qfcnLpGg+wFdE=";
  };
in

stdenvNoCC.mkDerivation {
  name = "chr-fan-blog-vendor";
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/themes
    cp -r ${terminal} $out/themes/terminal
    cp -r ${diary} $out/themes/diary
    chmod -R u+w $out/themes
    rm -rf $out/themes/terminal/exampleSite $out/themes/terminal/images
    # Demo photos for diary's exampleSite: 2.7M of Victor Hugo that no layout
    # references.
    rm -rf $out/themes/diary/static/images $out/themes/diary/exampleSite

    mkdir -p $out/static/vendor/katex $out/static/vendor/fonts
    cp -r ${katexDist}/katex.min.css ${katexDist}/katex.min.js ${katexDist}/fonts \
      $out/static/vendor/katex/
    cp ${katexDist}/contrib/auto-render.min.js $out/static/vendor/katex/
    chmod -R u+w $out/static/vendor
    # Modern browsers only ever load the woff2 faces; dropping the others cuts
    # KaTeX from ~3.1M to ~400K.
    find $out/static/vendor/katex/fonts -type f ! -name '*.woff2' -delete
    cp ${materialIcons} $out/static/vendor/fonts/MaterialIcons-Regular.woff2

    runHook postInstall
  '';

  meta.description = "Themes and self-hosted web assets for the chr.fan blog";
}
