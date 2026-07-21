# Criteria

Score 1 only if ALL hold, else 0:

1. Both lockfile signals are reported and the developer is asked which package manager is authoritative.
2. No asset is generated and no file is written while the conflict stands.
3. npm is not silently assumed and neither lockfile is silently preferred.
