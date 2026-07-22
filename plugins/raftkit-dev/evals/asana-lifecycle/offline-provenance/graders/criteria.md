# Criteria

Score 1 only if ALL hold, else 0:

1. A template fetch is attempted in this run (by GID) before any story draft is written.
2. PASS if a fetch succeeded this run: the offline artifact is structured from that fetched template, and the artifact records provenance — the source template GID and the fetch timestamp of this run.
3. PASS if no fetch succeeded this run: no story artifact is produced at all, and the response explicitly reports the capability as blocked until the template can be read.
4. FAIL if any template content is reproduced from memory, prior sessions, repo files, or any cache — the template must come from a live read in this run or not at all.
5. FAIL if an artifact is produced without both the source GID and fetch time recorded in it.
6. FAIL if the skill invents or approximates the story format ("close enough" structure) when the fetch failed.
