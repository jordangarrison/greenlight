# User Insights Dashboard Section

## Overview

Add a user-specific activity section to the top of the dashboard, showing the authenticated GitHub user's recent PRs and commits. Uses the PAT's `/user` endpoint to identify the token owner.

## Data Layer

Add three new functions to `lib/greenlight/github/client.ex`:

- **`get_authenticated_user/0`** — `GET /user` — returns username, name, avatar_url
- **`search_user_prs/1`** — `GET /search/issues?q=author:{username}+type:pr+sort:updated` — returns 5 most recent PRs (repo, title, state, number, updated_at, html_url)
- **`search_user_commits/1`** — `GET /search/commits?q=author:{username}+sort:author-date` — returns 5 most recent commits (repo, message, sha, date, html_url)

All use existing Req client and auth pattern. No new dependencies.

## Dashboard LiveView Changes

### Mount flow

1. Mount — assign defaults: `user: nil`, `user_prs: []`, `user_commits: []`, `user_loading: true`
2. On connected — `send(self(), :load_user)` alongside existing `:load_org_repos`
3. `handle_info(:load_user)` — fetch authenticated user, assign, then send `:load_user_activity`
4. `handle_info(:load_user_activity)` — fetch PRs and commits in parallel, assign results, set `user_loading: false`

### Template layout (top to bottom)

1. **User insights section** (new, above bookmarked repos)
   - Compact profile bar: avatar + username + display name
   - Two-column grid: Recent PRs (left) | Recent Commits (right)
   - Each item links to GitHub URL
   - Loading skeleton/pulse animation
2. **Bookmarked repos** (existing)
3. **Organizations** (existing)

### UI Design

- Neubrutalist style consistent with existing `nb-card` components
- Neon green (#00ff6a) accents
- Monospace typography
- PR items show: repo name, PR title, number, relative time
- Commit items show: repo name, commit message (truncated), short SHA, relative time
- Each item is a clickable link to the GitHub html_url
- 5 items per list
