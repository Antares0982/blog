#!/usr/bin/env bash
# Dump the published chr.fan WordPress content as JSON on stdout.
# Requires ssh access to the host running MariaDB (see ~/.ssh/config).
set -euo pipefail

HOST="${1:-antares}"
DB="${2:-wordpress}"

ssh "$HOST" "sudo mysql $DB -N --raw -e '
SET SESSION group_concat_max_len = 1000000000;
SELECT JSON_ARRAYAGG(JSON_OBJECT(
  \"id\", p.ID,
  \"type\", p.post_type,
  \"status\", p.post_status,
  \"slug\", p.post_name,
  \"guid\", p.guid,
  \"parent\", p.post_parent,
  \"title\", p.post_title,
  \"date\", p.post_date,
  \"modified\", p.post_modified,
  \"excerpt\", p.post_excerpt,
  \"md\", p.post_content_filtered,
  \"html\", p.post_content,
  \"views\", (SELECT meta_value FROM wp_postmeta m WHERE m.post_id=p.ID AND m.meta_key=\"views\"),
  \"cats\", (SELECT JSON_ARRAYAGG(t.name) FROM wp_term_relationships tr
             JOIN wp_term_taxonomy tt ON tt.term_taxonomy_id=tr.term_taxonomy_id
             JOIN wp_terms t ON t.term_id=tt.term_id
             WHERE tr.object_id=p.ID AND tt.taxonomy=\"category\"),
  \"tags\", (SELECT JSON_ARRAYAGG(t.name) FROM wp_term_relationships tr
             JOIN wp_term_taxonomy tt ON tt.term_taxonomy_id=tr.term_taxonomy_id
             JOIN wp_terms t ON t.term_id=tt.term_id
             WHERE tr.object_id=p.ID AND tt.taxonomy=\"post_tag\")
))
FROM wp_posts p
WHERE p.post_type IN (\"post\",\"page\") AND p.post_status IN (\"publish\",\"private\")
ORDER BY p.post_date;
'" 2>/dev/null
