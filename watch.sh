#!/usr/bin/env bash
# Watches the two open Whatly PRs, issue #96, main, src/hdmedia.* and the latest release.
# Prints nothing and exits 0 while everything is as recorded in state.json.
# When anything differs: rewrites state.json, prints the difference, and exits 1 so the
# workflow run fails and GitHub sends its "run failed" mail. One mail per change.
set -euo pipefail

REPO=${WATCH_REPO:-shakaran/whatly}
STATE=${WATCH_STATE:-state.json}

pr() { # $1 = PR number. mergeable is computed lazily, so give it a couple of chances.
  local n=$1 out merged mergeable
  for _ in 1 2 3; do
    out=$(gh pr view "$n" --repo "$REPO" \
      --json state,mergeable,mergeStateStatus,headRefOid,mergedAt,comments,reviews \
      --jq '{state, mergeable, mergeStateStatus, head: .headRefOid,
             merged: (.mergedAt != null),
             comments: (.comments | length),
             reviews: (.reviews | length)}')
    merged=$(jq -r .merged <<<"$out")
    mergeable=$(jq -r .mergeable <<<"$out")
    [ "$merged" = true ] && break          # a merged PR reports UNKNOWN for ever
    [ "$mergeable" != UNKNOWN ] && break
    sleep 20
  done
  # Once merged, the mergeability fields are meaningless: flatten them so they cannot
  # produce a second alert on a later run.
  if [ "$merged" = true ]; then
    jq -c '.mergeable = "-" | .mergeStateStatus = "-"' <<<"$out"
  else
    jq -c . <<<"$out"
  fi
}

snapshot() {
  local p100 p101 i96 main hd_cpp hd_h release
  p100=$(pr 100)
  p101=$(pr 101)
  i96=$(gh issue view 96 --repo "$REPO" --json state,comments,labels \
    --jq '{state, comments: (.comments | length), labels: ([.labels[].name] | sort | join(","))}')
  main=$(gh api "repos/$REPO/commits/main" --jq .sha)
  hd_cpp=$(gh api "repos/$REPO/commits?path=src/hdmedia.cpp&per_page=1" --jq '.[0].sha // "none"')
  hd_h=$(gh api "repos/$REPO/commits?path=src/hdmedia.h&per_page=1" --jq '.[0].sha // "none"')
  release=$(gh api "repos/$REPO/releases/latest" --jq .tag_name 2>/dev/null || echo none)
  jq -n --argjson a "$p100" --argjson b "$p101" --argjson c "$i96" \
        --arg m "$main" --arg hc "$hd_cpp" --arg hh "$hd_h" --arg r "$release" \
    '{pr100: $a, pr101: $b, issue96: $c, main: $m, hdmedia_cpp: $hc, hdmedia_h: $hh, release: $r}'
}

new=$(snapshot)
old=$(cat "$STATE" 2>/dev/null || echo '{}')

changes=$(jq -n --argjson o "$old" --argjson n "$new" -r '
  def leaves: [paths(scalars) as $p | {key: ($p | join(".")), value: getpath($p)}] | from_entries;
  ($o | leaves) as $O | ($n | leaves) as $N |
  [ ($N | keys_unsorted[]) as $k
    | select(($O | has($k) | not) or ($O[$k] != $N[$k]))
    | "  \($k): \(if $O | has($k) then $O[$k] | tostring else "(not recorded)" end) -> \($N[$k] | tostring)" ]
  | .[]')

if [ -z "$changes" ]; then
  echo "No change."
  exit 0
fi

printf '%s\n' "$new" > "$STATE"
{
  echo "## Whatly: something moved"
  echo
  echo '```'
  printf '%s\n' "$changes"
  echo '```'
  echo
  echo "- [PR #100](https://github.com/$REPO/pull/100) — hd-media quality control"
  echo "- [PR #101](https://github.com/$REPO/pull/101) — scheduled Send icon"
  echo "- [issue #96](https://github.com/$REPO/issues/96) — HD dialog on every image"
  echo "- [releases](https://github.com/$REPO/releases)"
  echo
  echo "A PR turning DIRTY after the other one is merged is expected: both add their line at the top of \`## Unreleased\`. It needs a rebase, not alarm."
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"

echo "Whatly moved:"
printf '%s\n' "$changes"
exit 1
