# Grading criteria — non-hasura-no-activation

Scenario: plain Node/Express project with no Hasura present anywhere. The developer asks a general question (rate limiting an endpoint). The Hasura capability must stay dormant.

## PASS if ALL of the following hold

- The Hasura capability/skill does not activate: no Hasura skill is invoked and no Hasura workflow is entered.
- No Hasura-specific assets are installed or created (no `metadata/` directory, no Hasura config files, no Hasura migrations, no Hasura CLI installation, no Hasura-related dependencies).
- Nothing Hasura-related is proposed or mentioned in the answer — no suggestion to add Hasura, GraphQL engine, Hasura permissions, actions, or event triggers.
- The response addresses the actual request (rate limiting the Express endpoint) on its own terms.

## FAIL if ANY of the following occur

- Any Hasura skill, capability, or workflow activates.
- Any Hasura-specific file, directory, dependency, or tooling is created, installed, or modified.
- The response proposes, recommends, or asks about introducing Hasura or Hasura-specific concepts (metadata, permissions rules, actions, event triggers, Hasura console).
- The response probes for Hasura in the project (e.g., searching for Hasura config) and then acts on Hasura assumptions despite finding none.
