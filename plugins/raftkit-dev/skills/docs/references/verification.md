# Verification — parity with evidence

`verify` is the completion gate: it either passes with evidence or refuses the
clean claim naming each missing item. It never softens a gap into "basically
done".

## The parity comparison

Compare, for the current approved story/change set:

- the approved story and the `spec_path` spec (what was promised),
- the code (what exists),
- the tests (what is proven),
- the living docs (what is described),
- diagrams the change set touches (what is depicted),
- relevant operational contracts (runbooks, deployment notes) when the story's
  scope includes them.

Any mismatch → the refusal names each missing parity item and points at the
sync path. All aligned → report the pass listing what was checked.

## The change-set input contract

Stale and no-impact decisions require a deterministic change set:

- an explicitly selected base/ref/diff (`--base <ref>` — refs validated, run
  without a shell, resolved to commit SHAs that are reported), or
- the user-confirmed current working diff, passed as an explicit list
  (`--changed <file|->`).

An invalid or ambiguous revision is bad input — never treated as an empty
change set. Renames are preserved (old and new paths both count for ownership
matching). With no change set supplied, stale/no-impact checks are reported as
`not evaluated — no change set provided`, never guessed.

## Evidence-backed no-impact

A correct no-impact outcome is allowed and must carry its evidence:

```
Docs: not impacted — <reason>
Inspected change set: <files> (<source, with SHAs when git-resolved>)
Documentation roots: <roots>
Ownership evidence: <the mapping source(s) consulted>
```

## Success strings

- `Docs: updated and verified — <n> file(s), history recorded` — after a
  confirmed sync re-verified clean.
- The no-impact block above, when true.

Machine output goes to stdout or an explicit `--out` path inside the repository
root — no unsolicited report files, and temporary artifacts are cleaned after
verification.

## Incident-evidence branch

When verification runs for a production incident (from the Incident PR Handoff,
not a story), the operational-docs element is produced against the **explicit
containment change set** using this skill's ordinary evidence forms: an in-scope
runbook/known-failure update, an evidence-backed `Docs: not impacted — <reason>`
naming the inspected incident change set, or a drafted follow-up task. There is
no second lifecycle and no invented spec; the incident change set (with its SHA)
is the scope. Story-mode verification is unchanged.
