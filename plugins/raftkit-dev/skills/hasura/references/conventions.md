# Project conventions

Every path, stage name, port and naming pattern this skill uses is discovered from the repository or the Project Profile, never assumed. Concrete values anywhere in this skill are examples of one project's naming.

Discover once per repository and write the result to `.raftkit/hasura.json` so later runs read it instead of re-deriving it. Re-derive when that file is absent, or when a command fails in a way that suggests it is stale.

Every path, stage name, port, and naming pattern below is a **convention
discovered from the repository or the Project Profile**, not a constant of
this skill. Before doing anything, establish:

- **`<hasura-root>`** — the Hasura project directory: locate `config.yaml`
  (the Hasura CLI config) plus sibling `migrations/` and `metadata/`
  directories. Example: `services/hasura`.
- **`<schema-snapshot>`** — the committed schema snapshot the project keeps
  honest (DBML, SQL dump, or similar) and the Make target that refreshes it.
  Example: `docs/schema.dbml` via `make create-dbml`.
- **Make targets and stage names** — read the Makefile. Targets like
  `hasura-migrate`, `hasura-migrate-status`, `hasura-env`, `hasura-export`
  and stages like `local` / `development` / `production` are examples of one
  project's naming; use whatever this repo actually defines.
- **Env-file location** — where per-stage Hasura env files live and how they
  are decrypted. Example: `<hasura-root>/console/.env.<stage>`,
  gpg-encrypted, decrypted via `make hasura-env stage=<stage>`.
- **Database name** — from `metadata/databases/`; `default` is the common
  example.
- **Roles** — from existing permission YAML. `user` / `service` /
  `anonymous` (with `admin` implicit) is a typical set; discover the real
  one.
- **Tenancy model** — the tenant column/relationship (e.g. an `org_id`,
  `team_id`, or `family_id` FK) that scopes user-visible rows. Discover it
  from existing tables and permission filters; never assume one.
- **Secret env var names** — from the env files and metadata. Examples:
  `ACTION_BASE_URL`, `HASURA_GRAPHQL_ADMIN_SECRET`,
  `HASURA_EVENT_TRIGGER_SECRET`, header `x-hasura-event-secret`.
- **Webhook path convention** — from existing event triggers. Example:
  `/internal/<path>` on the actions base URL.
- **Deploy remotes / branch model** — from the Project Profile or git
  config. Some projects have a deploy remote that accepts only one ref;
  never push feature branches to such a remote.

"the discovered value". Concrete paths appear only as clearly-marked
examples.

## Environment

Discover these from the repo (Makefile, docker-compose, env files) — the
values below are one project's example layout:

- Migration env files: `<hasura-root>/console/.env.<stage>` (may be
  encrypted on disk; decrypt via the project's env target, e.g.
  `make hasura-env stage=<stage>`, before querying).
- Local DB port: whatever docker-compose / the Makefile defines (example:
  `localhost:54324` via `make hasura-up stage=local`). The snapshot target
  may hardcode this endpoint — check it.
- Shared `updated_at` trigger function: many projects install one (example:
  `public.set_updated_at()` in a migration like
  `<ts>_add_uuid_defaults_and_updated_at_triggers`). If one exists, do not
  redefine it — new tables just add `CREATE TRIGGER
  set_<table>_updated_at`. Discover its name and installing migration from
  the migrations directory.

## When something goes wrong

- **Snapshot refresh fails** (local Hasura down) → scaffolder falls back to
  the cached `<schema-snapshot>` with a warning and continues. Bring local
  Hasura up (example: `make hasura-up stage=local`) for a fresh snapshot.
- **Collision detected** → scaffolder prints the existing snapshot block +
  remediation (`Use add-column / rename instead.`) and exits. Never
  overwrites.
- **`hasura-query.sh` says the stage env file is missing** → run the env
  decrypt target (example: `make hasura-env stage=<stage>`) first.
- **Generated YAML breaks `metadata apply`** → it shouldn't (templates
  enforce filter-nesting indentation + a structural YAML test), but if it
  does: export metadata from local (example: `make hasura-export
  stage=local`) to normalize what's there, then diff against the generated
  YAML to spot the drift.

## Integrations

This skill activates only on a detected Hasura project
(`scripts/detect-hasura.mjs`; a non-Hasura repository gets nothing) and wires
into the rest of raftkit-dev:

- **capability-preflight / setup-project** — Hasura is a conditional capability
  in the provider registry; preflight reports its readiness and setup-project
  proposes activation only for a detected Hasura project, behind human
  approval. Discovery of the project's conventions (roots, stages, Make
  targets, secret env var names, tenancy relationship) runs through the same
  convention-discovery seam — nothing is assumed.
- **envx** — when the project keeps encrypted environments, the admin secret
  and endpoint are sourced through envx (the secret is never echoed; env files
  are never logged).
- **docs schema/architecture sync** — a schema change that lands here triggers
  the docs skill's change-tracking lifecycle so the schema and architecture
  docs stay in lockstep; the DBML snapshot refresh feeds that sync.
