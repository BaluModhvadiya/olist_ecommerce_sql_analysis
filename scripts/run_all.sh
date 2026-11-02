#!/usr/bin/env bash
# Rebuilds the whole project end to end:
#   schema -> load -> views -> every analysis (saved to results/) -> charts
#
# Uses the standard PG* environment variables, e.g.
#   export PGHOST=localhost PGUSER=postgres PGDATABASE=olist
set -euo pipefail
cd "$(dirname "$0")/.."

PSQL="psql -X -v ON_ERROR_STOP=1 -q"

[ -f data/olist_orders_dataset.csv ] || bash scripts/download_data.sh

echo "1/4  Creating schema";        $PSQL -f sql/01_schema.sql
echo "2/4  Loading CSVs";           $PSQL -f sql/02_load.sql
echo "3/4  Creating views";         $PSQL -f sql/03_views.sql

echo "4/4  Running analyses"
mkdir -p results
for f in sql/analysis/*.sql; do
    name=$(basename "$f" .sql)
    $PSQL -f "$f" -o "results/${name}.txt"
    echo "     results/${name}.txt"
done

python3 scripts/make_charts.py
echo "Done."
