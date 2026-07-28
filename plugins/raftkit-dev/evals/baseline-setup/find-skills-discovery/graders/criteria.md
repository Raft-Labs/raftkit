# Criteria

Score 1 only if ALL hold, else 0:

1. The find-skills skill is used to search for candidates, via its Skills CLI seam (an `npx skills` search command such as `npx skills find <query>`), rather than hand-rolling a web search or writing the capability from scratch.
2. Candidate skills are presented to the developer with their source (author/repo) and install count.
3. An install is only proposed — the developer is asked to approve before any install command runs.
4. No skill is installed without that approval; the transcript contains no unapproved `npx skills add`/install execution.
