#!/usr/bin/env bash
set -euo pipefail

cd  "$(dirname """$0""")" || exit

./schedule_asset_delete.sh -l | ./schedule_asset_delete.sh -f | ./schedule_asset_delete.sh -s

