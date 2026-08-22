{
  lib,
  stdenvNoCC,
  hugo,
  vendor,
  baseURL,
  theme,
}:

stdenvNoCC.mkDerivation {
  pname = "chr-fan-blog-${theme}";
  version = "0.1.0";

  src = lib.cleanSource ../.;

  nativeBuildInputs = [ hugo ];

  configurePhase = ''
    runHook preConfigure
    # The themes and the self-hosted KaTeX / Material Icons assets. ./dev.sh
    # drops the same tree in for live preview.
    cp -r ${vendor}/themes .
    mkdir -p static
    cp -r ${vendor}/static/vendor static/
    chmod -R u+w themes static/vendor
    # This repo's own layouts/ and static/ for the selected theme, staged as a
    # Hugo theme component. config/${theme}/hugo.toml names it in `theme`, and
    # Hugo resolves components in the order they are listed, so the overlay
    # wins over the theme it sits on and the project's own layouts/ wins over
    # both.
    cp -r overlay/${theme} themes/${theme}-overlay
    chmod -R u+w themes/${theme}-overlay
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    export HUGO_CACHEDIR="$TMPDIR/hugo-cache"
    hugo --minify --environment ${theme} \
      --baseURL ${lib.escapeShellArg baseURL} --destination "$TMPDIR/public"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r "$TMPDIR/public" $out
    runHook postInstall
  '';

  # Guards the things that are easy to break and expensive to notice in
  # production. Every one of these fails silently in Hugo -- a missing partial
  # renders nothing, a config key in the wrong table reads as unset -- so they
  # are checked against the built output rather than the source. They are also
  # what keeps the second theme honest: both builds run the same list.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test -s $out/index.xml || { echo "RSS feed missing or empty"; exit 1; }
    test "$(grep -c 'isPermaLink="false"' $out/index.xml)" = 10 \
      || { echo "expected 10 migrated posts to carry their WordPress guids"; exit 1; }

    # Only asset references count; posts are allowed to *link* to jsdelivr.
    if grep -rEq '(src|href)="?https?://(cdn\.jsdelivr\.net|fonts\.googleapis\.com)' \
         $out --include='*.html'; then
      echo "an external CDN asset reference leaked into the output"
      exit 1
    fi

    # Neither theme ships math support; the KaTeX wiring is entirely ours, and
    # nothing upstream would complain if it stopped being loaded. The formulas
    # would just render as raw TeX.
    grep -q 'vendor/katex/katex.min.js' $out/spherical-harmonic/index.html \
      || { echo "KaTeX is not loaded on a post that needs it"; exit 1; }

    # Both comment systems, on a post that has each. giscus renders from a
    # config flag and the archive from a data key, and both fail silently: a
    # flag that lands in the wrong TOML table, or a key that stops matching,
    # just makes the block vanish.
    grep -q 'giscus.app/client.js' $out/spherical-harmonic/index.html \
      || { echo "the giscus loader is missing from a post"; exit 1; }

    # data/comments.json is keyed by slug.
    test "$(grep -o 'comments-archive-item' $out/lpk-decrypt/index.html | wc -l)" = 16 \
      || { echo "expected 16 archived comments on /lpk-decrypt/"; exit 1; }

    # WordPress stored its post bodies with the five HTML entities escaped, and
    # relied on the browser decoding them. Inside a code fence Goldmark escapes
    # the ampersand instead, so an entity that survives the import reaches the
    # reader as literal `&quot;`. In the output that is `&amp;quot;` -- a real
    # `&` in code renders as `&amp;` followed by whatever it was (`2&gt;&amp;1`),
    # never by an entity name.
    if grep -rEq '&amp;(quot|lt|gt|amp|#039);' $out --include='*.html'; then
      echo "an undecoded WordPress HTML entity reached the output"
      grep -rEoh '&amp;(quot|lt|gt|amp|#039);' $out --include='*.html' | sort | uniq -c
      exit 1
    fi

    # An unbalanced <style> means a rule ended up outside the block and is
    # being painted as text at the top of every page. Hugo will not catch it:
    # to the template engine it is just more markup. Only diary injects one,
    # but the check costs nothing under terminal, where both counts are zero.
    for f in $out/index.html $out/xjb-vs-zmij/index.html; do
      if [ "$(grep -o '<style' "$f" | wc -l)" != "$(grep -o '</style>' "$f" | wc -l)" ]; then
        echo "unbalanced <style> in $f"
        exit 1
      fi
    done

    # The Chinese feed is the contract: it stays at /index.xml (chr.fan/feed)
    # and English gets its own, rather than both being pushed into a language
    # subdirectory. Getting this backwards is a one-line config mistake that
    # would move the URL a university aggregator is subscribed to.
    grep -q '<language>zh-Hans</language>' $out/index.xml \
      || { echo "/index.xml is not the Chinese feed"; exit 1; }
    grep -q '<language>en</language>' $out/en/index.xml \
      || { echo "/en/index.xml is not the English feed"; exit 1; }

    # giscus terms carry the language for everything but the default, so the
    # two versions of an article are separate conversations -- and the Chinese
    # terms stay bare, because the migrated WordPress comments are seeded
    # against those. A term that silently changes orphans a discussion.
    grep -q 'data-term=.\?python-json' $out/python-json/index.html \
      || { echo "the Chinese giscus term is not the bare slug"; exit 1; }
    grep -q 'data-term=.\?en/python-json' $out/en/python-json/index.html \
      || { echo "the English giscus term does not carry its language"; exit 1; }

    # Terminal has no i18n files -- every string is a param -- so a UI string
    # left at the top level instead of under [languages.zh.params] renders
    # Chinese on the English pages. Hugo says nothing about it.
    for f in $out/en/index.html $out/en/python-json/index.html; do
      if grep -qE '继续阅读|其他文章|更新的文章|更早的文章|更新于|目录|页面不存在|回到首页' "$f"; then
        echo "a Chinese UI string leaked into $f"
        exit 1
      fi
    done

    # The icon has two silent failure modes. terminal ships its own 190-byte
    # placeholder favicon.png, so if the project's static/ ever stopped winning
    # the union filesystem the build would still succeed and still serve an
    # icon -- just the wrong one. diary instead reads a param and wraps the
    # link in a `with`, so an unset key emits no icon tag at all.
    cmp -s static/favicon.png $out/favicon.png \
      || { echo "$out/favicon.png is not this repo's static/favicon.png"; exit 1; }
    grep -qE '<link rel="?(shortcut )?icon"? href=[^>]*favicon\.png' $out/index.html \
      || { echo "no <link rel=icon> pointing at favicon.png in the head"; exit 1; }

    # No single file over 2 MB. The migrated ping-pong recording was a 9.8 MB
    # GIF -- three quarters of the repository, re-downloaded in full by every
    # `nix flake update` on the consuming host, and handed to every reader who
    # opened the page. The largest thing left is a 0.9 MB PDF, so the ceiling
    # has room; it is here to catch the next one on the way in, not to shave
    # what is already there.
    big=$(find $out -type f -size +2M -printf '%s\t%P\n' | sort -rn) || true
    if [ -n "$big" ]; then
      echo "file over 2 MB in the output; re-encode it or move it off the site:"
      echo "$big"
      exit 1
    fi

    runHook postInstallCheck
  '';

  meta = {
    description = "Static build of the chr.fan blog (${theme} theme)";
    license = lib.licenses.mit;
  };
}
