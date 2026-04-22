# Adapter Reference — git-flow

Details for the GitHub, GitLab, and Azure DevOps PR adapters.

---

## How adapters work

`create-pr.sh` resolves the title, body, and base branch, then delegates to:

```
adapters/<PR_HOST>/pr.sh
```

Each adapter receives resolved values via environment variables:

| Variable          | Set by             | Description               |
| ----------------- | ------------------ | ------------------------- |
| `PR_TITLE`        | create-pr.sh       | Final PR title            |
| `PR_BODY`         | create-pr.sh       | PR description / body     |
| `PR_BASE`         | create-pr.sh       | Target branch             |
| `PR_DRAFT`        | create-pr.sh       | `true` or `false`         |
| `PR_WORK_ITEM_ID` | create-pr.sh       | Tracker ID (may be empty) |
| `REPO_OWNER`      | caller environment | Org / namespace           |
| `REPO_NAME`       | caller environment | Repository name           |

---

## GitHub adapter

**File:** `adapters/github/pr.sh`

### Required env

```bash
export GITHUB_TOKEN=ghp_...   # Fine-grained or classic PAT
export REPO_OWNER=acme        # GitHub org or username
export REPO_NAME=platform     # Repository name
```

### Token scopes needed

- `repo` (for private repos) or `public_repo` (for public repos)
- Specifically: `pull_requests: write`

### API used

`POST https://api.github.com/repos/{owner}/{repo}/pulls`

### Dedup query

`GET /pulls?state=open&head={owner}:{branch}&base={base}`

### Work item linking

Body is set to the PR_BODY resolved by create-pr.sh.
For GitHub Issues: add `Closes #{id}` to the PR_BODY or PR_TEMPLATE.
For external trackers: add `Ref: {url}`.

---

## GitLab adapter

**File:** `adapters/gitlab/pr.sh`

### Required env

```bash
export GITLAB_TOKEN=glpat-...  # Personal or project access token
export REPO_OWNER=acme         # GitLab namespace (user or group)
export REPO_NAME=platform      # Repository / project name
export GITLAB_HOST=gitlab.com  # Optional (default: gitlab.com)
```

### Token scopes needed

- `api` scope (includes merge requests read/write)

### API used

`POST https://{host}/api/v4/projects/{namespace%2Frepo}/merge_requests`

### Draft MRs

GitLab draft MRs prepend `Draft: ` to the title. This is handled automatically when `--draft` is passed to `create-pr.sh`.

### Dedup query

`GET /merge_requests?state=opened&source_branch={branch}&target_branch={base}`

### Remove source branch on merge

The adapter sets `remove_source_branch: true` by default (GitLab best practice).

---

## Azure DevOps adapter

**File:** `adapters/ado/pr.sh`

### Required env

```bash
export ADO_TOKEN=...           # Personal Access Token
export REPO_OWNER=acme         # ADO organization name
export REPO_NAME=platform      # Repository name
export ADO_PROJECT=MyProject   # ADO project name
```

### Token scopes needed

- `Code: Read & Write`

### API used

`POST https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}/pullrequests?api-version=7.1-preview.1`

### Work item linking

When `PR_WORK_ITEM_ID` is set, the adapter passes a `workItemRefs` array to the API, which creates a formal ADO work item ↔ PR link in the board.

### Dedup query

`GET /pullrequests?sourceRefName=refs/heads/{branch}&targetRefName=refs/heads/{base}&status=active`

---

## Adding a new adapter

1. Create `adapters/<host>/pr.sh`
2. Read env vars: `PR_TITLE`, `PR_BODY`, `PR_BASE`, `PR_DRAFT`, `PR_WORK_ITEM_ID`, `REPO_OWNER`, `REPO_NAME`
3. Implement deduplication (check for existing open PR on same source branch)
4. Output JSON matching the contract:

```json
{
  "id": 1234,
  "url": "https://...",
  "title": "...",
  "linked_work_item_id": 11111,
  "deduped": false
}
```

5. Exit 0 on success, non-zero on failure (with `{"error": "..."}` to stdout)
6. Add `<host>` as a valid value in `create-pr.sh`'s validation regex
