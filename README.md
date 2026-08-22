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

## Adding English

Decided, not built: there is no English content in this repo yet, and declaring
the language before there is would publish an empty English site with a
selector pointing at it. When en.chr.fan moves over, English goes at
`chr.fan/en/` -- one Hugo site, one nginx vhost, and `en.chr.fan/*` 301s to
`chr.fan/en/*`.

Content needs no renaming. With `defaultContentLanguage = "zh"` an unsuffixed
`content/posts/foo.md` already *is* the Chinese page; the translation is
`content/posts/foo.en.md` and Hugo pairs them by base filename.

`config/_default/languages.toml`:

```toml
[zh]
  languageName = "中文"
  title = "α-Lyrae"
  weight = 1
  hasCJKLanguage = true
  [zh.params]
    rssLanguage = "zh-Hans"
  # the current [[menu.main]] from config/<theme>/hugo.toml moves here
[en]
  languageName = "English"
  weight = 2
  [en.params]
    rssLanguage = "en"
```

plus `defaultContentLanguage = "zh"` and `defaultContentLanguageInSubdir =
false` in `config/_default/hugo.toml`, and `showLanguageSelector = true` in the
terminal config.

Three things to get right:

**`rssLanguage` has to move under each language.** It is a single global value
today, and the feed template reads
`.Site.Params.rssLanguage | default .Site.Language.Lang`. Left at the top level
the English feed would advertise itself as `zh-Hans`. Everything else is safe:
with the default language out of a subdirectory, the Chinese feed stays at
`/index.xml` (`chr.fan/feed`) and English gets its own at `/en/index.xml`.

**giscus terms collide.** `data-term` is the slug, so `/python-json/` and
`/en/python-json/` would land in the same discussion and the English page would
show the Chinese comments. The term needs the language folded in for anything
that is not the default one, unless sharing a thread is what you want.

**The theme's selector only links language home pages.** It renders
`$.Site.Home.AllTranslations`, not `.Translations` of the current page, so it
never deep-links a reader to the translation of the post they are reading. That
needs a partial of our own in `overlay/terminal/`.

The English UI strings need no work: every one of Terminal's is a param whose
fallback is already English, so `[en.params]` simply omits the Chinese ones.

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
