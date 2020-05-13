#!/usr/bin/env bash

set -euo pipefail

########################################################
# Schedule a Workflow with ID asset-delete in Opencast #
# This script takes no arguments. Please hard-code     #
# your desired values.                                 #
#
# Usage: ./schedule_asset_delete.sh -l | \
#        ./schedule_asset_delete.sh -f | \
#        ./schedule_asset_delete.sh -s
########################################################

# Opencast admin URL
OC_ADMIN_URL="https://stable.opencast.org"

# The user name of an Opencast admin user
OC_USER="opencast_system_account"

# The password of an Opencast admin user
OC_PASSWORD="CHANGE_ME" #"CHANGE_ME"

# Workflow ID to use for scheduling
OC_WF_ID="asset-delete"

# Days in the past - do not touch episodes with newer snapshots
SNAPSHOTS_MUST_BE_OLDER_THAN=30

# Minimum number of snapshots that will trigger a clean up
SNAPSHOT_COUNT_THRESHOLD=100

# Opencast archive
OC_ARCHIVE_DIR="/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org"

# Maximum number of workflows to be allowed to run on the system
# This script will schedule WFs until this number is reached.
OC_MAX_CONCURRENT_WFS=8

# Time in s to wait between each Workflow Schedule
SLEEP_TIME=5

# Additional cURL options, like --insecure for broken HTTPS
CURL_OPT="--silent"

# output the episode (UU)IDs efficiently
list_episodes_in_archive() {
  cd "$OC_ARCHIVE_DIR"
  echo ./** | tr " " "\n" | grep -oE '\b[0-9a-f]{8}\b-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-\b[0-9a-f]{12}\b'
}

# input (pipe): episode IDs. One per line.
# only forward (in pipe) those episodes whose newest contents are older than
# SNAPSHOTS_MUST_BE_OLDER_THAN days
filter_episodes_by_modified_date() {
  while IFS= read -r episode_id; do
      cd  "$OC_ARCHIVE_DIR/$episode_id"

      number_of_subdirs=$(find "$OC_ARCHIVE_DIR/$episode_id/" -maxdepth 1 -type d | wc -l)
      ((number_of_subdirs--))
      (("$number_of_subdirs" < "$SNAPSHOT_COUNT_THRESHOLD")) && continue

      number_of_files_newer=$(find . -mtime -"${SNAPSHOTS_MUST_BE_OLDER_THAN}" | wc -l)
      (("$number_of_files_newer" > "0")) && continue

      echo "$episode_id"
  done
}

# get number of currently Workflow Instances
get_number_of_running_wf() {
  ret=$(curl $CURL_OPT -f --digest -u "${OC_USER}:${OC_PASSWORD}" -H "X-Requested-Auth: Digest" \
      "${OC_ADMIN_URL}/api/workflows?filter=state%3Arunning&limit=10")
  # shellcheck disable=SC2181
  [ $? -ne "0" ] && echo "Get Number of Running WFs failed" && exit
  len="${#ret}"
  [ "$len" -lt "5" ] && echo "0" && return

  number=$(echo "$ret" | grep -o '}\s*,\s*{' | wc -l)
  ((number++))
  echo "$number"
}

is_wf_running_on_episode() {
  episode_id="$1"
  url="${OC_ADMIN_URL}/api/workflows?filter=state%3Arunning%2Cevent_identifier%3A${episode_id}&limit=10"
  ret=$(curl $CURL_OPT -f --digest -u "${OC_USER}:${OC_PASSWORD}" -H "X-Requested-Auth: Digest" "$url")
  # shellcheck disable=SC2181
  [ $? -ne "0" ] && echo "Get Running WFs on episode failed" && return 1
  len="${#ret}"
  [ "$len" -ge "5" ] && echo "1" || echo "0"
}

schedule_wf() {
  episode_id="$1"

  running_wf=$(is_wf_running_on_episode "$episode_id")
  [ "$running_wf" -eq "1" ] && echo "[WARN] There is a running WF instance on $1. Skipping." && return

  echo "Scheduling WF $OC_WF_ID on $episode_id for execution"
  ret=$(curl $CURL_OPT -f --digest -u "${OC_USER}:${OC_PASSWORD}" -H "X-Requested-Auth: Digest" \
      "${OC_ADMIN_URL}/api/workflows/" \
      -F "event_identifier=$episode_id" \
      -F "workflow_definition_identifier=$OC_WF_ID" )
  echo "$ret"
}

schedule_wfs() {
  while IFS= read -r episode_id; do

    while [ "$(get_number_of_running_wf)" -gt "$OC_MAX_CONCURRENT_WFS" ]; do
      echo "Waiting 10s for system load to decline."
      sleep 10
    done
    echo "Currently running $(get_number_of_running_wf) WFs"

    schedule_wf "$episode_id"
    sleep "$SLEEP_TIME"
  done
}

info() {
  echo "Currently running $(get_number_of_running_wf) WFs"
}

help() {
  echo "Usage: "
  echo "   $0 -l | $0 -f | $0 -s"
}

[ $# -eq 0 ] && help && exit
key="$1"

case $key in
    -l|--list)
    list_episodes_in_archive
    shift
    ;;
    -f|--filter)
    filter_episodes_by_modified_date
    shift
    ;;
    -s|--schedule)
    schedule_wfs
    shift
    ;;
    -i|--info)
    info
    shift
    ;;
    *)    # unknown option
    help
    shift
    ;;
esac
