# PR and Commit Full Views Design

## Overview

Extend the dashboard's "Recent Pull Requests" and "Recent Commits" sections with clickable "View all" links that navigate to dedicated full-view pages with pagination.

## Routes

```
/:username/pulls    -> UserPullsLive
/:username/commits  -> UserCommitsLive
```

- Username is part of the URL to support viewing other users' activity in the future
- Pagination via query param: `?page=N` (default: 1)
- Page size: 10 items per page
- Total cached items: 50

## Architecture

### Data Flow

```
Dashboard / Full View LiveViews
        |
UserInsightsServer.get_cached()  (read from cache)
        |
UserInsightsServer (polls every 5 min)
        |
Greenlight.GitHub.list_user_prs(username, %{per_page: 50})
Greenlight.GitHub.list_user_commits(username, %{per_page: 50})
        |
ManualRead Actions (extract per_page from query.arguments)
        |
GitHub.Client (accepts optional per_page param)
        |
GitHub REST API (/search/issues, /search/commits)
```

### Changes by Layer

#### 1. GitHub Client (`lib/greenlight/github/client.ex`)

- `search_user_prs/2` and `search_user_commits/2` accept an optional opts map
- Extract `per_page` from opts, default to 50
- Pass through to GitHub API query params

#### 2. Ash Resources (`user_pr.ex`, `user_commit.ex`)

- Add optional `argument(:per_page, :integer)` to the `list` action on both resources
- `allow_nil?` defaults to `true` so it's optional

#### 3. ManualRead Actions (`actions/list_user_prs.ex`, `actions/list_user_commits.ex`)

- Extract `per_page` from `query.arguments`, filter nils
- Pass as opts map to Client functions
- Follows existing pattern from `ListWorkflowRuns`

#### 4. Domain (`domain.ex`)

- No changes needed to `define` calls
- Optional args passed as map: `Greenlight.GitHub.list_user_prs(username, %{per_page: 50})`

#### 5. UserInsightsServer (`user_insights_server.ex`)

- Change `per_page` from 5 to 50 in `fetch_user_insights/0`
- Pass `%{per_page: 50}` through the Ash domain calls
- Cached data structure unchanged, just more items

#### 6. Dashboard LiveView (`dashboard_live.ex`)

- Add "View all ->" links next to "Recent Pull Requests" and "Recent Commits" headers
- Links point to `/:username/pulls` and `/:username/commits`
- Use `Enum.take(5)` to slice the first 5 items for the preview cards

#### 7. New LiveViews

**`UserPullsLive`** (`lib/greenlight_web/live/user_pulls_live.ex`)
- Mounts with `username` param from URL
- `handle_params` reads `page` from query string (default 1)
- Reads from `UserInsightsServer.get_cached()` if username matches authenticated user
- Paginates with `Enum.slice(items, (page - 1) * 10, 10)`
- Same card style as dashboard for consistency
- Pagination controls: Previous / Next with page indicator

**`UserCommitsLive`** (`lib/greenlight_web/live/user_commits_live.ex`)
- Same pattern as `UserPullsLive` but for commits

#### 8. Router (`router.ex`)

- Add routes in the authenticated `live_session`:
  ```elixir
  live "/:username/pulls", UserPullsLive
  live "/:username/commits", UserCommitsLive
  ```

## Pagination Logic

```elixir
page = max(String.to_integer(params["page"] || "1"), 1)
page_size = 10
total_items = length(all_items)
total_pages = max(ceil(total_items / page_size), 1)
page = min(page, total_pages)
items = Enum.slice(all_items, (page - 1) * page_size, page_size)
```

## Future Considerations

- When `username` does not match the authenticated user, fetch on-demand from the GitHub API instead of reading from cache
- Could increase cached items beyond 50 or add search/filtering
