#!/usr/bin/env bash
#
# fetch-logs.sh — download real sample log datasets for benchmarking.
#
# Source: loghub (https://github.com/logpai/loghub), a large collection of real
# production/system log datasets curated for log-analytics research. We pull the
# 2k-line samples that loghub hosts directly on GitHub. These are real-world log
# lines (Linux, SSH, Apache, HDFS, etc.) — ideal replay material for hammering a
# log pipeline like Axoflow.
#
# Usage: ./scripts/fetch-logs.sh [dest_dir]
#
set -euo pipefail

DEST="${1:-testdata/logs}"
BASE="https://raw.githubusercontent.com/logpai/loghub/master"

# dataset_path_on_loghub  ->  local_filename
declare -A DATASETS=(
  ["Linux/Linux_2k.log"]="linux.log"
  ["OpenSSH/OpenSSH_2k.log"]="openssh.log"
  ["Apache/Apache_2k.log"]="apache.log"
  ["HDFS/HDFS_2k.log"]="hdfs.log"
  ["Zookeeper/Zookeeper_2k.log"]="zookeeper.log"
  ["Mac/Mac_2k.log"]="mac.log"
  ["HealthApp/HealthApp_2k.log"]="healthapp.log"
)

mkdir -p "$DEST"
echo "Fetching real sample logs from loghub into: $DEST"

for path in "${!DATASETS[@]}"; do
  out="$DEST/${DATASETS[$path]}"
  url="$BASE/$path"
  printf '  %-28s -> %s\n' "$path" "$out"
  curl -fsSL "$url" -o "$out"
done

# Note: pointing axobench at this directory replays ALL .log files together as
# one heterogeneous stream (the loader concatenates a directory), so there's no
# need for a separate combined file.

echo
echo "Done. Line counts:"
wc -l "$DEST"/*.log 2>/dev/null | sort -n
