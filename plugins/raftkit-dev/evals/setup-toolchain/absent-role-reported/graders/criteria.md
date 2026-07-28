# Criteria

Score 1 only if ALL hold, else 0:

1. The generated assets run only the present scripts (lint, test) via the detected manager.
2. The absent typecheck role is reported by name in the run/report output — not silently skipped, and no typecheck command is generated.
3. No script or flag absent from the manifest appears anywhere in the assets.
