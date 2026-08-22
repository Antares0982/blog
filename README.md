# chr.fan

Hugo source for [chr.fan](https://chr.fan), migrated off WordPress + Sakurairo.

Currently deployed at **blog.chr.fan**; the apex domain still runs WordPress
until the cutover.

## Layout

| Path | |
|---|---|
| `content/posts/` | posts, one file per article, served at `/<slug>/` |
| `content/*.md` | the old WordPress *pages*; `hidden: true` keeps them out of the post stream and the feed, exactly as WordPress had them |
| `layouts/` | templates that are the same under either theme: the feed and the comment archive |
| `overlay/<theme>/` | this repo's `layouts/` and `static/` for one theme |
| `config/_default/` | config shared by both themes |
| `config/<theme>/` | that theme's `theme`, params and menu |
| `nix/vendor.nix` | both themes + self-hosted KaTeX and Material Icons |
| `nix/site.nix` | the build |
| `scripts/` | the one-shot WordPress migration, kept runnable |

`themes/` and `static/vendor/` are generated, not source.

## Two themes

The site builds under either [terminal](https://github.com/panr/hugo-theme-terminal)
(the default) or [diary](https://github.com/AmazingRise/hugo-theme-diary), from
one branch. Hugo does the switching itself, with no conditionals in any
template:

- `hugo --environment <theme>` merges `config/<theme>/hugo.toml` over
  `config/_default/hugo.toml`.
- That file sets `theme = ["<theme>-overlay", "<theme>"]`. `nix/site.nix` stages
  `overlay/<theme>/` as `themes/<theme>-overlay`, and Hugo resolves theme
  components in the order listed, so the overlay wins over the theme and the
  project's own `layouts/` wins over both.

This matters because the two themes cannot share a `layouts/` directory: diary
needs a `partials/head.html` override, and a file at that path would shadow
terminal's own `head.html` and break it. Keeping each theme's overrides in its
own component is what makes one branch possible.

Both builds run the same installCheck list, so neither theme can quietly lose
the feed, the comment archive, KaTeX or giscus.

## Two languages

Chinese is the default and stays at the site root, so `chr.fan/feed` -- the URL
a university aggregator is subscribed to -- never moves. English lives under
`/en/`.

`content/posts/foo.md` *is* the Chinese page; `foo.en.md` beside it is the
translation, paired by base filename. Nothing needed renaming for this.

en.chr.fan is still its own WordPress install, with the one article that has
been translated. It keeps serving until the apex cutover, at which point it
301s to `chr.fan/en/`; the date-prefixed permalinks need a regex, since the old
URLs are `/2026/01/07/python-json/`.

`scripts/import-wordpress.py` takes the language as its second argument and
picks the origin and timezone from it. The two installs disagree about the
latter -- chr.fan is Asia/Shanghai, en.chr.fan was left at UTC -- so reading
one site's offset for the other silently shifts the post eight hours.

Three things that are load-bearing here, each of which fails silently:

- **giscus terms carry the language** for everything but the default, so
  `/python-json/` and `/en/python-json/` are separate conversations. The
  Chinese terms stay bare slugs, because the migrated WordPress comments are
  seeded against those.
- **`rssLanguage` is per language.** Left at the top level the English feed
  advertises itself as `zh-Hans`.
- **Terminal has no i18n files** -- every UI string is a param -- so anything
  left in the shared `[params]` renders Chinese on the English pages. diary
  carries its own `i18n/zh.yaml` and needs none of this.

The build fails on all three.

## Build

```sh
nix build                 # -> ./result, terminal, what the server gets
nix build .#blog-diary    # the other theme, for comparison
./dev.sh                  # live preview on http://localhost:1313
./dev.sh diary            # ... under diary
```

The Nix repo consumes this flake as an input and points nginx at
`packages.blog` (or `packages.blog-apex` after the cutover, which differs only
in `baseURL`). See `server/hk/blog.nix` there.

## Things that are load-bearing

**RSS guids.** A university RSS aggregator subscribes to `chr.fan/feed`. It has
already seen every pre-migration post under the guid WordPress minted for it,
so `layouts/index.rss.xml` emits each post's original guid verbatim from the
`wpguid` front-matter key. These are *not* reconstructible from the post ID —
the oldest one is `http://43.129.210.213/?p=1`, the bare IP of the server that
predated the domain. Change this and all ten posts get re-pushed to every
subscriber. `nix/site.nix` fails the build if the count of preserved guids
drops.

**No external assets.** Neither theme ships math support, so KaTeX is vendored
under `static/vendor/katex` and loaded from there; diary additionally wants
Material Icons from fonts.googleapis.com. cdn.jsdelivr.net and Google Fonts are
both render-blocking and both slow to unreachable from mainland China. The
build fails if a CDN asset reference appears in the output, and fails if KaTeX
stops being loaded on a post that needs it.

**giscus keys on the slug, not the path.** `data-mapping = "specific"` with
`data-term` set to the page slug, because eight pages have changed path since
the migration and the slug survives the move back to the apex domain too.
Switching to `pathname` orphans every existing discussion.

**LaTeX backslashes.** wp-editormd ran posts through a Markdown filter that
collapsed `\\` to `\`, so the author had to type `\\\\` to get a LaTeX row
break. Hugo's passthrough extension hands math to KaTeX untouched, so
`scripts/import-wordpress.py` halves those runs on the way in. If you ever
re-import, keep that.

**View counts.** `views` in front matter is the total a post carried over from
WordPress and is rendered into the HTML directly, so the number is right with
JavaScript off. `/api/views.json` carries only the hits since the migration and
is added on top; it is produced on a timer from the nginx access log, not by a
service in the request path.
