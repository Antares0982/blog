#!/usr/bin/env bash
# Dump the approved chr.fan WordPress comments as JSON on stdout.
# Requires ssh access to the host running MariaDB (see ~/.ssh/config).
#
# Comment emails are deliberately not selected: the archive is public and the
# addresses are not ours to publish.
set -euo pipefail

HOST="${1:-antares}"
DB="${2:-wordpress}"

ssh "$HOST" "sudo mysql $DB -N --raw -e '
SET SESSION group_concat_max_len = 1000000000;
SELECT JSON_ARRAYAGG(JSON_OBJECT(
  \"id\", c.comment_ID,
  \"post\", c.comment_post_ID,
  \"slug\", p.post_name,
  \"parent\", c.comment_parent,
  \"date\", c.comment_date,
  \"author\", c.comment_author,
  \"url\", c.comment_author_url,
  \"type\", c.comment_type,
  \"content\", c.comment_content
))
FROM wp_comments c JOIN wp_posts p ON p.ID=c.comment_post_ID
WHERE c.comment_approved=1
ORDER BY c.comment_post_ID, c.comment_date;
'" 2>/dev/null
