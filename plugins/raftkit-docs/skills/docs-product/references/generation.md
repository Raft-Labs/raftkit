# Generation and verification

## Postures

- **Greenfield** — recommend and generate the full tree: the root CLAUDE.md and README; foundation docs (tech stack, architecture overview with its diagrams, decisions, glossary, design guidelines, NFRs, RBAC matrix, changes-log); one folder per module (overview, features, APIs, schemas, test plan; workflows, state machines, async jobs, observability and compliance where they apply); index registries.
- **Living docs** — the discovered convention is the yardstick. Map each capability onto its structure, naming and history convention. Generate only what the design produced and the convention fits. Restructure nothing.
- **Hybrid** — additions land only through an approved proposal showing exact paths and content.

## Templates

`assets/templates/` ships nine: readme, CLAUDE.md, architecture overview, module, feature, REST API, DBML schema, ADR, test plan. Fill each from the confirmed design; complete or explicitly mark every placeholder. A doc with no template follows the nearest one and the tree in the CLAUDE.md template.

## Rules

- Generate nothing before the phase-8 sign-off. Ask where a capability lands; never guess.
- Match code samples to the chosen archetype. Never mix archetypes.
- Carry the repo's history convention: version tables or verification footers.
- Never generate stories or bugs: drafting is `raftkit-pm:story`, filing is `raftkit-qa:bug`.

## Diagrams

Mermaid only. One caption line above each. Identical node names across diagrams. Split past ~30 nodes. Walk the inventory; generate what applies and write `N/A — <reason>` for the rest. Never skip one silently.

- Project-wide, in the architecture overview: system architecture, request lifecycle, data flow, deployment topology, auth flow, tenancy model, module map, async architecture, permission flow.
- Per module: components and page navigation. Per feature: a sequence. Per stateful entity: a state diagram. Per async job: its execution. Per workflow: a swimlane.

A change that affects a diagram regenerates it and bumps its version.

## Verification (phase 10)

Grade every gap: P0 blocks done, P1 should be fixed, P2 is cosmetic. `raftkit-dev:docs`'s `scripts/validate-docs.mjs --graded` emits the same grading. Check:

- the foundation docs the convention expects;
- each module's docs, and the conditional ones its design needs;
- every edge-case category answered or N/A;
- cross-references resolve and every index lists every doc;
- one code archetype throughout;
- diagram coverage;
- docs against code, where code exists.

The graded report goes to refinement (phase 11).
