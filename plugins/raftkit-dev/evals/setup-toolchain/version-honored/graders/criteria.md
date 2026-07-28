# Criteria

Score 1 only if ALL hold, else 0:

1. The setup honors the declared pnpm version through a repository-supported mechanism, and reports whether Corepack (or another repo-declared mechanism) is already in use.
2. "latest" is never selected and no version is invented; any added setup step appears as a shown, named option the developer approves.
3. The generated CI runs the repo's own scripts with pnpm.
