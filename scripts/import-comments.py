#!/usr/bin/env python3
"""Convert the chr.fan WordPress comments into data/comments.json.

Input is the JSON produced by scripts/export-comments.sh.

The comments are read-only history: WordPress is going away and giscus takes
every new comment, so this runs once and the result is committed. It is
idempotent, though, so it can be re-run while the database is still around.

Run:  scripts/export-comments.sh > scripts/wp-comments.json \
        && scripts/import-comments.py scripts/wp-comments.json
"""

import html
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Rendered without an author link, and flagged so the template can badge it.
OWNER = "Antares0982"

# The comment box on WordPress ran the Sakura theme's emoticon picker, which
# inserted the QQ emoji set as `{{name}}` (and, in 2021, as `:name:`). The
# images belong to a theme that is being deleted, so the codes are mapped onto
# the nearest Unicode face instead of dragging six PNGs along.
EMOJI = {
    "weixiao": "\U0001F60A",   # 微笑
    "se": "\U0001F60D",        # 色
    "fadai": "\U0001F610",     # 发呆
    "haixiu": "\U0001F633",    # 害羞
    "dianzan": "\U0001F44D",   # 点赞
    "huaji": "\U0001F60F",     # 滑稽
}

# The only tags that appear in fourteen years of comments are <p>, <a> and
# <code>; everything else is escaped rather than trusted. This is user-supplied
# text going onto a public page, so the whitelist is deliberate and closed.
TAG = re.compile(r"</?(?:p|br|code)\s*/?>|<a\b[^>]*>|</a>", re.I)
HREF = re.compile(r"""\bhref\s*=\s*["']([^"']+)["']""", re.I)


def safe_url(url):
    """Only absolute http(s), so no javascript: or data: sneaks through."""
    url = (url or "").strip()
    return url if re.match(r"https?://[^\s\"'<>]+$", url) else ""


def emojify(text):
    text = re.sub(r"\{\{(\w+)\}\}", lambda m: EMOJI.get(m.group(1), m.group(0)), text)
    return re.sub(r":(\w+):", lambda m: EMOJI.get(m.group(1), m.group(0)), text)


def wpautop(text):
    """WordPress applied this at render time, so the stored text has bare
    newlines where the page showed paragraphs and line breaks."""
    paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    return "".join("<p>" + p.replace("\n", "<br>") + "</p>" for p in paras)


def sanitize(raw):
    raw = raw.replace("\r\n", "\n").replace("\r", "\n")
    out, opened = [], []
    pos = 0
    for m in TAG.finditer(raw):
        out.append(emojify(html.escape(html.unescape(raw[pos:m.start()]))))
        tag = m.group(0)
        low = tag.lower()
        if low.startswith("<a"):
            href = HREF.search(tag)
            url = safe_url(html.unescape(href.group(1))) if href else ""
            # A whitelisted <a> whose href is unusable keeps its text and loses
            # the link, rather than emitting a dangling or hostile one.
            opened.append(bool(url))
            if url:
                out.append(f'<a href="{html.escape(url)}" rel="nofollow noopener ugc" target="_blank">')
        elif low == "</a>":
            if opened.pop() if opened else False:
                out.append("</a>")
        else:
            out.append(low.replace(" ", "").replace("/>", ">"))
        pos = m.end()
    out.append(emojify(html.escape(html.unescape(raw[pos:]))))
    out.extend("</a>" for ok in opened if ok)
    body = "".join(out).strip()
    # WordPress ran wpautop over every comment at render time, so the stored
    # text leans on it for both paragraphs and line breaks. Comments written in
    # the admin editor already carry their own <p> and only need the breaks.
    return body.replace("\n", "<br>") if "<p>" in body.lower() else wpautop(body)


def hugo_slugs():
    """wpid -> the slug the post actually lives at.

    Read from the content tree rather than duplicating import-wordpress.py's
    SLUG_OVERRIDES, and it drops comments on anything that was never migrated.
    """
    slugs = {}
    for base, _, files in os.walk(os.path.join(ROOT, "content")):
        for name in files:
            if not name.endswith(".md"):
                continue
            with open(os.path.join(base, name)) as f:
                fm = f.read().split("---", 2)[1]
            wpid = re.search(r"^wpid:\s*(\d+)", fm, re.M)
            slug = re.search(r'^slug:\s*"([^"]+)"', fm, re.M)
            if wpid and slug:
                slugs[int(wpid.group(1))] = slug.group(1)
    return slugs


def main(path):
    slugs = hugo_slugs()
    rows = [c for c in json.load(open(path)) if c["type"] == "comment"]

    by_id = {}
    for c in rows:
        by_id[c["id"]] = {
            "id": c["id"],
            "author": c["author"],
            "url": "" if c["author"] == OWNER else safe_url(c["url"]),
            "owner": c["author"] == OWNER,
            # Stored in the site's local time, UTC+8, same as the posts.
            "date": c["date"].replace(" ", "T") + "+08:00",
            "html": sanitize(c["content"]),
            "replies": [],
        }

    parent_of = {c["id"]: c["parent"] for c in rows}

    def root_of(cid):
        while parent_of.get(cid):
            cid = parent_of[cid]
        return cid

    out = {}
    for c in sorted(rows, key=lambda c: (c["post"], c["date"])):
        slug = slugs.get(c["post"])
        if not slug:
            continue
        node = by_id[c["id"]]
        if not c["parent"]:
            out.setdefault(slug, []).append(node)
            continue
        # GitHub-style single level of nesting: a reply to a reply joins the
        # same thread and says who it was aimed at. WordPress allowed three
        # levels and exactly one comment (728) used the third.
        node["reply_to"] = by_id[c["parent"]]["author"]
        by_id[root_of(c["id"])]["replies"].append(node)

    for thread in out.values():
        for node in thread:
            node["replies"].sort(key=lambda n: n["date"])

    dest = os.path.join(ROOT, "data", "comments.json")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")

    total = sum(1 + len(n["replies"]) for t in out.values() for n in t)
    print(f"wrote {dest}: {total} comments on {len(out)} posts")


if __name__ == "__main__":
    main(sys.argv[1])
