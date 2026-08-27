# whatly-watch

Watches [shakaran/whatly](https://github.com/shakaran/whatly) every six hours and stays silent unless something moves.

What it looks at: PRs [#100](https://github.com/shakaran/whatly/pull/100) and [#101](https://github.com/shakaran/whatly/pull/101) — state, mergeability, head commit, review and comment counts; issue [#96](https://github.com/shakaran/whatly/issues/96) — state, comment count, labels; the tip of `main`; the last commit to touch `src/hdmedia.cpp` or `src/hdmedia.h`; and the latest release tag.

How it tells me: when anything differs from `state.json` the run **fails on purpose**, which is what makes GitHub send its "run failed" mail. The run summary carries the before-and-after lines. `state.json` is then rewritten and committed, so the next run is green and one change costs one mail. Nothing is posted to the whatly repo and no issue is opened anywhere.

If the mail never arrives, check GitHub → Settings → Notifications → Actions → Email. Scheduled-run failures are mailed to whoever last touched the cron line in `.github/workflows/watch.yml`.

To see it work without waiting: Actions → Whatly watch → Run workflow.

To stop it: Actions → Whatly watch → ⋯ → Disable workflow.

Known limits. GitHub's scheduled runs are frequently late, sometimes by more than an hour, so treat six hours as approximate. A new release is reported here, but installing it is still done by hand on the laptop. A PR turning `DIRTY` right after the other one is merged is expected rather than alarming: both add their entry at the top of `## Unreleased` in `CHANGELOG.md`, so whichever is merged second needs a one-line rebase.
