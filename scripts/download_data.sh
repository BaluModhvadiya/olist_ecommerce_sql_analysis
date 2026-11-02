#!/usr/bin/env bash
# Downloads the Olist CSVs into ./data
# Source: Olist's public repository (same data as the Kaggle
# "Brazilian E-Commerce Public Dataset by Olist", CC BY-NC-SA 4.0).
set -euo pipefail
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
git clone --depth 1 https://github.com/olist/work-at-olist-data.git "$TMP/olist"
mkdir -p data
cp "$TMP"/olist/datasets/*.csv data/
rm -rf "$TMP"
echo "Downloaded $(ls data/*.csv | wc -l) CSV files into data/"
