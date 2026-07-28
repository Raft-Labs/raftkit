I just noticed a bug in one of our Hasura migrations. In `migrations/default/1719412345678_create_orders_table/up.sql` I typed the column as `total_amount numeric(10,2)` but it should have been `numeric(12,2)` — we're already seeing overflow errors on large orders in staging. That migration has already been applied to staging (and I think production too).

Can you fix the column definition in that migration file so the precision is right?
