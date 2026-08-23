# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

`README.md` is the architecture document and is kept current: the two-theme
component layout, the two-language setup, and the list of load-bearing
invariants (RSS guids, no external CDN assets, giscus slug mapping, LaTeX
backslashes, view counts) all live there. Read it first. This file covers only
what is not in it -- how to build and check things, and the traps that have
actually cost a build cycle.

## Build and check

`hugo` is not on PATH. Everything goes through the flake.

```sh
nix build                 # terminal, what the server gets -> ./result
nix build .#blog-diary    # the other theme
nix build .#blog-apex     # identical but baseURL = https://chr.fan/
./dev.sh [terminal|diary] # live preview on http://localhost:1313
nix fmt                   # nixfmt-tree, for nix/ and flake.nix
```

There is no test suite and no linter. `installCheckPhase` in `nix/site.nix` is
the test suite, it runs on every build, and both themes run the same list --
so `nix build && nix build .#blog-diary` is the full check. There is no way to
run one assertion alone; the phase is a shell script and it exits on the first
failure.

**Every check there guards something Hugo fails silently on.** A missing
partial renders nothing, a config key in the wrong TOML table reads as unset, a
static file that stops winning the union filesystem is replaced by the theme's
own copy of the same name. That is why the checks read the built output rather
than the source. When you fix a bug of that shape, add the check in the same
commit -- that is the established pattern and the reason the file is as long as
it is.

Several checks are pinned to specific content:

| Check | Pinned to |
|---|---|
| 10 preserved WordPress guids | the count of migrated posts |
| KaTeX and giscus loaded | `/spherical-harmonic/` |
| 16 archived comments | `/lpk-decrypt/` |
| unbalanced `<style>` | `/` and `/xjb-vs-zmij/` |
| no Chinese UI string | `/en/` and `/en/python-json/` |

Adding or removing content can move these numbers. Update the check, do not
loosen it.

## Traps

**`nix build` reads the git tree, not the working directory.** An untracked
file does not exist as far as the build is concerned, while a modified tracked
file is picked up normally. Adding `static/foo.png` and building gives you the
theme's `foo.png` with no warning. `git add` new files before building --
`./dev.sh` does not have this problem, which makes the discrepancy worse.

**TOML sub-tables swallow everything after them.** A bare key written below
`[params.giscus]` belongs to `params.giscus`, not `params`. Hugo reads the
misplaced key as unset and says nothing. This has broken giscus once already.
Keep bare keys above every sub-table in a `[params]` block.

**Static file precedence** is project `static/` > `overlay/<theme>/static/` >
`themes/<theme>/static/`. Both themes ship their own `favicon.png` and
`og-image.png`, so a precedence slip substitutes theme art silently rather than
404ing. Both are checked by byte comparison for that reason.

**The two themes reach the same feature by different routes** and a change to
one is usually not a change to the other. The favicon is hardcoded in
terminal's head partial and a `params.favicon` key in diary's; `og:image` is
hardcoded in terminal and comes from the site `images` param via Hugo's
internal opengraph template in diary. Check both builds' `index.html`, not just
the default theme's.

**`themes/` and `static/vendor/` are generated** by `./dev.sh` and by the Nix
build, and are gitignored. Never edit them; the edit belongs in
`overlay/<theme>/` or in `nix/vendor.nix`.

## Content

`content/posts/*.md` are posts, served at `/<slug>/`. `content/*.md` are the
old WordPress pages, each carrying `hidden: true` and an explicit `url:`, which
keeps them out of the post stream and the feed. `foo.en.md` beside `foo.md` is
its English translation; Hugo pairs them by base filename.

Front matter keys this repo adds on top of Hugo's own:

- `wpguid` -- the guid WordPress minted, emitted verbatim in the feed. Never
  edit or drop one on a migrated post. See README.
- `wpid` -- the WordPress post ID, for tracing back to the export. Inert.
- `views` -- the WordPress view total, rendered into the HTML directly;
  `/api/views.json` adds post-migration hits on top at runtime.
- `hidden` -- keeps a page out of the post stream and the feed.
- `slug` -- also the giscus discussion term and the `data/comments.json` key.
  Changing it orphans both.

`data/comments.json` is the read-only archive of migrated WordPress comments,
keyed by slug, with `html` pre-sanitised against a closed whitelist by
`scripts/import-comments.py`. New comments go to giscus.

## Migration scripts

`scripts/` is the one-shot WordPress migration, kept runnable rather than
deleted. It needs ssh access to the host running MariaDB and is not part of any
build. Post IDs 305 and 3 are deliberately excluded in `import-wordpress.py`;
**305 was a private WordPress page and this repository is public.** Do not
migrate it.

## Deploying

This repo is a flake input of the private Nix configuration repo, which points
nginx at `packages.blog` from `server/hk/blog.nix`. Pushing here changes
nothing on the server. The change ships when that repo runs

```sh
nix flake update blog --flake ./hosts/hk
sudo nixos-rebuild switch --flake ./hosts/hk#hk
```

so a commit here is only half the work, and the lock bump belongs in its own
commit over there.
