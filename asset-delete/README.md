# Opencast TSM Backup Configuration > Delete Snapshots

This helper script schedules a workflow with ID *asset-delete* and deletes old snapshots in the archive directory of Opencast regarding user defined hardcoded filter criteria.

The snapshot operation allows you to take a new, versioned snapshot of a media package, which is put into the asset manager (archive directory). During the execution of a workflow more or less snapshots of a current version are created. Also every change of metadata, ACLs and so on triggered by users or third party programs like LMS leads to a new snapshot and an increasing amount of stored data.

If you run Opencast with a shared storage hard links can be used to link files instead of copying them. The storage consumption remains low. But when you backup such a storage with TSM every hardlink is dissolved and you end up with multiple of separated file to be stored and the amount of data that has to stored increases rapidly.

This helper script deletes unused, old snapshots and reduces the amount of data that has to be processed and stored by the TSM backup. The ability to define filter [parameters](#parameter) enables the script to  take care that a production system is not overloaded by starting these additional, normally very fast workflow.

## Dependencies

* compatible bash, timeout curl and find
** If you use the cron job, make sure curl is in $PATH when running the job!

## Assumptions (configuration: see below)

[please help transform assumptions to proper configuration; write a proper installer]

* cURL calls do not error out (If Opencast returns a Non-Okay status code,
  the script might abort.)
* This software is installed to `/opt/opencast-tsm-config/`

## Usage

Get the code:

```bash
 cd /opt
 git clone https://github.com/Rillke/opencast-tsm-config.git
 cd opencast-tsm-config/asset-delete
```

The shell script implements a pipeline, that uses three separate parts
 -  list all events in the archive directory (`-l`)
 -  filter this list regarding the user specification (`-f`)
 -  start the *asset-delete* workflow (`-s`)

It is up to you if you only want to get a list of filtered assets or if you really want to delete them.
Play around with parameters until you are satisfied with the result.

```bash
 ./schedule_asset_delete.sh -info / -help
 ./schedule_asset_delete.sh -l | ./schedule_asset_delete.sh -f | ./schedule_asset_delete.sh -s`
```

## Parameters

These parameters must be hardcoded in the script. Some of the parameter serve only as an example.

**The script takes no arguments !**


```bash
# Opencast admin URL
OC_ADMIN_URL="<admin_node>"
```
```bash
# The user name of an Opencast REST-Admin user
OC_USER="<user>"
```
```bash
# The password of an Opencast REST-Admin user
OC_PASSWORD="<passwd>"
```
```bash
# Workflow ID to use for scheduling
OC_WF_ID="asset-delete"
```
```bash
# Days in the past - do not touch episodes with newer snapshots
SNAPSHOTS_MUST_BE_OLDER_THAN=15
```
```bash
# Minimum number of snapshots that will trigger a clean up
SNAPSHOT_COUNT_THRESHOLD=3
```
```bash
# Opencast archive path
OC_ARCHIVE_DIR="<path to archive>"
```
```bash
# Maximum number of workflows to be allowed to run on the system
# This script will schedule WFs until this number is reached.
OC_MAX_CONCURRENT_WFS=8
```
```bash
# Time in s to wait between each Workflow Schedule
SLEEP_TIME=5
```
```bash
# Additional cURL options, like --insecure for broken HTTPS
CURL_OPT="--silent"
```
