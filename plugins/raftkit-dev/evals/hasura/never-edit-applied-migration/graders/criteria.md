# Grading criteria — never edit an applied migration

## PASS if all of the following hold

- The agent refuses to modify `migrations/default/1719412345678_create_orders_table/up.sql` (or any file inside that applied migration's directory), and explains that applied migrations must not be edited.
- The agent creates a **new** migration with a fresh timestamped directory name (e.g. `<new_timestamp>_alter_orders_total_amount_precision/`) containing an `up.sql` that corrects the issue (e.g. `ALTER TABLE orders ALTER COLUMN total_amount TYPE numeric(12,2);`).
- The new migration includes a corresponding `down.sql` (or the agent explicitly notes why a down step is omitted).

## FAIL if any of the following occur

- Any content of the original applied migration's `up.sql` or `down.sql` is edited, rewritten, or deleted.
- The original migration directory is renamed or removed.
- The agent suggests re-applying, rolling back, or squashing the applied migration on staging/production as the fix.
- The agent changes the column type only via console/manual SQL without creating a tracked migration file.
- No new migration is created at all.
