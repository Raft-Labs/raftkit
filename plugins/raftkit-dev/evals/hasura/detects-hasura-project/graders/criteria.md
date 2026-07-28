# Grading criteria — detects-hasura-project

Scenario: the repository contains a Hasura `config.yaml`, a `metadata/` directory, and a `migrations/` directory. The developer asks to add a `notifications` table. The Hasura capability must recognize the project and work from what it finds.

## PASS if ALL of the following hold

- The Hasura capability/skill activates: the agent recognizes this as a Hasura project from the signals present (`config.yaml`, `metadata/`, `migrations/`).
- The agent inspects the repository to discover the project's actual layout before acting — reading `config.yaml` and/or listing the metadata and migrations directories to learn the project root(s), metadata directory, and migrations directory in use.
- The agent reports back what it discovered (e.g., where the Hasura project root is, which metadata and migrations directories it will use) rather than silently assuming defaults.
- The table-creation work proceeds using the discovered locations and existing project conventions (migration placement, metadata structure), not hardcoded or guessed paths.

## FAIL if ANY of the following occur

- The Hasura capability does not activate despite the Hasura signals in the repository, and the agent treats this as a generic SQL/database task.
- The agent assumes paths, directory names, or environment/stage names without inspecting the repository (e.g., writing to a guessed `hasura/migrations/default/` without checking what exists).
- The agent invents project structure that contradicts what is actually on disk, or creates a parallel Hasura setup instead of using the existing one.
- The agent proceeds to create files without ever surfacing the discovered conventions it is following.
