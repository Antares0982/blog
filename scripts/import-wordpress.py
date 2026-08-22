#!/usr/bin/env python3
"""Convert the chr.fan WordPress export into Hugo content.

Input is the JSON produced by scripts/export-wordpress.sh, which pulls
`post_content_filtered` -- wp-editormd stores the author's original Markdown
there, so nothing has to be reverse-engineered out of rendered HTML.

Run:  scripts/export-wordpress.sh > scripts/wp-export.json
      scripts/import-wordpress.py scripts/wp-export.json

      scripts/export-wordpress.sh antares wordpress_en > scripts/wp-export-en.json
      scripts/import-wordpress.py scripts/wp-export-en.json en
"""

import html
import json
import os
import re
import sys
from urllib.parse import quote, unquote

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# One WordPress install per language, each with its own origin to strip and its
# own idea of local time -- post_date is stored in whatever the site was set to,
# and en.chr.fan was left at UTC while chr.fan is Asia/Shanghai. Reading +08:00
# off the English post would have shifted it eight hours in the feed.
SITES = {
    "zh": ("https://chr.fan", "+08:00"),
    "en": ("https://en.chr.fan", "+00:00"),
}
DEFAULT_LANG = "zh"

# Set from SITES by main(); the conversion helpers read them.
SITE, TZ = SITES[DEFAULT_LANG]

# Post IDs deliberately left behind. 305 was a `private` page in WordPress and
# the Hugo repo is public, so migrating it would publish it. 3 was the privacy
# policy, which described cookies only WordPress ever set.
SKIP_IDS = {305, 3}

# The three slugs that were Chinese. Percent-encoded paths are unpleasant to
# share and were the root of two separate key-mismatch bugs (the view counter
# and the giscus mapping), since browsers do not normalise %XX case and the
# WordPress links in search results are lowercase while Hugo emits uppercase.
# server/hk/blog.nix in the Nix repo 301s the old paths here.
SLUG_OVERRIDES = {
    172: "arch-pitfalls",
    157: "all-going-well",
    325: "2022-dusk",
}

# Media swapped out on the way in, keyed by the markdown the export actually
# contains. The ping-pong recording was a 9.8 MB GIF -- three quarters of this
# whole repository, and a rude thing to hand a phone. Re-encoded to h264 it is
# 0.49 MB with the same 111 frames, and lives outside wp-content/ because it is
# no longer a WordPress upload: scripts/fetch-uploads.sh must not try to pull
# it off the old server.
#
# The width is inline rather than in a stylesheet because the two themes style
# post bodies from different files and this is one shared line of content.
MEDIA = {
    "![](/wp-content/uploads/2021/12/GIF%202022-1-1%2019-44-40.gif)": (
        '<video src="/media/pingpong-simulation.mp4" style="max-width:100%"'
        " autoplay loop muted playsinline controls></video>"
    ),
}


# `$$...$$` / `$...$` / `\[...\]` / `\(...\)`. Block form first so the greedy
# inline rule never splits a display block in half.
MATH = re.compile(r"\$\$.*?\$\$|\\\[.*?\\\]|\$[^$\n]+?\$|\\\(.*?\\\)", re.S)


def split_math(text):
    """Yield (is_math, chunk) covering the whole string."""
    pos = 0
    for m in MATH.finditer(text):
        if m.start() > pos:
            yield False, text[pos:m.start()]
        yield True, m.group(0)
        pos = m.end()
    yield False, text[pos:]


def fix_math(chunk):
    r"""Undo wp-editormd's backslash doubling.

    The Markdown filter WordPress ran turned `\\` into `\`, so the author had
    to type `\\\\` to get a LaTeX row break out the other end. Hugo's
    passthrough extension hands math to KaTeX untouched, so those four
    backslashes would now render as two row breaks. Halve any run of four.
    """
    return re.sub(r"\\{4}", r"\\\\", chunk)


# WordPress escaped these five on the way into post_content_filtered, and its
# own pipeline handed the result to a browser, which decoded them again. Hugo
# does not: inside a code fence Goldmark emits the text verbatim and escapes the
# ampersand, so `&quot;` reaches the reader as `&quot;`. Outside code it happens
# to look right, because the browser still decodes it -- which is why this only
# ever showed up in code blocks.
#
# Spelled out rather than handed to html.unescape, which also decodes the
# semicolon-less legacy names. Posts here contain `2>&1`, `&filename=` and an
# image called `canada.json_load&dump.svg`, and a stray `&not` or `&times` in
# that company would be silently rewritten.
ENTITIES = [("&quot;", '"'), ("&#039;", "'"), ("&lt;", "<"), ("&gt;", ">"),
            # Last, so a double-escaped `&amp;quot;` decodes exactly one level.
            ("&amp;", "&")]


def unescape(md):
    for entity, char in ENTITIES:
        md = md.replace(entity, char)
    return md


def convert_body(md):
    md = md.replace("\r\n", "\n").replace("\r", "\n")
    md = unescape(md)
    md = "".join(fix_math(c) if is_math else c for is_math, c in split_math(md))
    # Every origin, not just this language's. The English post embeds its
    # figures from https://chr.fan/wp-content/ -- the same files, uploaded once
    # to the Chinese site -- and links back to the Chinese article by absolute
    # URL. Left alone, an English page served from blog.chr.fan would be
    # fetching images from the WordPress install we are about to switch off.
    #
    # Uploads keep their WordPress path so links shared elsewhere still resolve;
    # only the origin is dropped, which also makes the tree domain-agnostic for
    # the eventual move back to the apex domain.
    for origin, _ in SITES.values():
        md = md.replace(f"{origin}/wp-content/", "/wp-content/")
        # Internal cross-links between posts, in either language.
        md = re.sub(rf"{re.escape(origin)}/(?!wp-content/)", "/", md)
    # After the origin is stripped, so the keys are the paths as written above.
    for old, new in MEDIA.items():
        md = md.replace(old, new)
    return md.strip() + "\n"


def yaml_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def yaml_list(items):
    return "[" + ", ".join(yaml_str(i) for i in items) + "]"


def page_path(p, by_id, overrides=True):
    """The URL this page is served at.

    Pages are hierarchical: a child of `words` lives at /words/<slug>/, not at
    /<slug>/, and WordPress 301s the flat form to it. Posts are flat, under the
    /%postname%/ permalink structure.

    With overrides=False this reconstructs the path WordPress used, which is
    what the redirects and the link rewriting need.
    """
    parts = []
    node = p
    seen = set()
    while node is not None and node["id"] not in seen:
        seen.add(node["id"])
        parts.append(slug_of(node) if overrides else unquote(node["slug"]))
        node = by_id.get(node.get("parent") or 0)
    return "/" + "/".join(reversed(parts)) + "/"


def slug_of(p):
    return SLUG_OVERRIDES.get(p["id"], unquote(p["slug"]))


def build_retargets(by_id):
    """old path -> new path, for the entries whose slug was overridden.

    Posts cross-link each other by path, so renaming a slug without fixing
    those leaves dead links inside the content. Both percent-encoding cases are
    covered because the bodies were written by hand over several years and use
    whichever the editor produced at the time.
    """
    out = {}
    for wpid in SLUG_OVERRIDES:
        p = by_id.get(wpid)
        if p is None:
            continue
        original = dict(p, slug=p["slug"])
        old = page_path(original, by_id, overrides=False).rstrip("/")
        new = page_path(p, by_id).rstrip("/")
        for variant in (old, quote(old, safe="/"), quote(old, safe="/").lower()):
            out[variant] = new
    return out


def retarget(text, retargets):
    for old, new in retargets.items():
        text = text.replace(old, new)
    return text


def main(path, lang=DEFAULT_LANG):
    global SITE, TZ
    SITE, TZ = SITES[lang]
    # Hugo pairs translations by base filename, so the Chinese page keeps the
    # bare name -- it is the default language -- and English becomes
    # `<slug>.en.md` beside it.
    suffix = "" if lang == DEFAULT_LANG else f".{lang}"

    posts = json.load(open(path))
    by_id = {p["id"]: p for p in posts}
    retargets = build_retargets(by_id)
    written = []
    for p in posts:
        if p["id"] in SKIP_IDS:
            continue
        slug = slug_of(p)
        title = html.unescape(p["title"])
        body = p["md"] or p["html"]
        is_post = p["type"] == "post"

        fm = [
            "---",
            f"title: {yaml_str(title)}",
            f"slug: {yaml_str(slug)}",
            f'date: {p["date"].replace(" ", "T")}{TZ}',
            f'lastmod: {p["modified"].replace(" ", "T")}{TZ}',
            # Kept so the RSS feed can reproduce WordPress's guid exactly; see
            # layouts/index.rss.xml. Copied verbatim rather than rebuilt from
            # the ID: the oldest post's guid still names the bare IP of the
            # server that predated the domain.
            f'wpid: {p["id"]}',
            f'wpguid: {yaml_str(p["guid"])}',
        ]
        if p.get("views"):
            fm.append(f'views: {int(p["views"])}')
        # "Uncategorized" is WordPress's word for no category at all, which is
        # what the English post has; it is not a category worth publishing.
        cats = [c for c in (p.get("cats") or []) if c != "Uncategorized"]
        if cats:
            fm.append(f"categories: {yaml_list(cats)}")
        if p.get("tags"):
            fm.append(f'tags: {yaml_list(p["tags"])}')
        if not is_post:
            # WordPress pages never appeared in the post stream or the feed.
            fm.append("hidden: true")
            # Pages are hierarchical, so the path cannot be derived from the
            # slug alone; `url` pins the whole thing. Setting it flat here is
            # what put five pages on the wrong URL in the first migration.
            fm.append(f"url: {yaml_str(page_path(p, by_id))}")
        if p["status"] == "private":
            fm.append("draft: true")
        fm.append("---\n")

        subdir = "posts" if is_post else ""
        out = os.path.join(ROOT, "content", subdir, slug + suffix + ".md")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w") as f:
            f.write("\n".join(fm) + "\n" + retarget(convert_body(body), retargets))
        written.append(out)

    # Every upload the posts actually reference; the rest of the 367M uploads
    # directory is Sakurairo wallpaper and does not come along.
    assets = set()
    for p in posts:
        if p["id"] in SKIP_IDS:
            continue
        assets.update(re.findall(r"/wp-content/uploads/[^\s\)\"'<>]+", convert_body(p["md"] or p["html"])))
    # Per language, so an English run does not truncate the Chinese list that
    # scripts/fetch-uploads.sh reads.
    with open(os.path.join(ROOT, "scripts", f"assets{suffix}.txt"), "w") as f:
        f.write("\n".join(sorted(assets)) + "\n")

    print(f"wrote {len(written)} files, {len(assets)} referenced uploads")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else DEFAULT_LANG)
