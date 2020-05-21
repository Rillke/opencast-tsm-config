# Opencast TSM Backup Configuration > Exclude Hardlinks


## How to avoid data duplication? The general idea.

TSM comes with some configuration like
[`inclexcl.list`](https://www.ibm.com/support/knowledgecenter/SSEQVQ_8.1.6/client/t_cfg_crtinclexcl.html).

In this list, one can specify files that should be excluded from or included
into the backup.

How can we use this list to create a backup with only relevant but all
necessary data?

1. Find all file names that share one inode (i.e. are hard links) above a
   certain size.
2. Consider one of the files in the set of files with the same inode as
   "original"¹, preferably the first occurrence of the file in Opencast's
   snapshot history.
3. Exclude all files found in 1. minus those considered "original" (2.) from
   backup by writing their paths into `inclexcl.list`.
4. Create a script that will restore the hard links (e.g. doing
   `ln original file_in_snapshot_10.mp4` ) and include this file in the backup.
5. In order to free space in backup/on tape immediately, tell TSM to delete
   everything from existing backups that is listed in the exclude list.

¹ We are aware that with hard links no true "original" exists.

## Dependencies

* compatible TSM
* compatible PHP-CLI [please help to get rid]
* compatible sh and find

## Configuration/ assumptions

[please help transform assumptions to proper configuration; write a proper installer]

* Opencast archive data is under: /opt/nfsexport/opencast_prod/opencast/archive
* Opencast does not delete snapshots containing "original" files while creating
  new snapshots after the exclude list has been created and before the
  "original" file was backed up.
* TSM client and config is under: `/opt/tivoli/tsm/client/ba/bin`
* TSM include/exclude file was copied to `/opt/tivoli/tsm/client/ba/bin/inclexcl.list.base`
* This software is installed to `/opt/opencast-tsm-config/`

## What does this software?

* exclude_list.php: PHP Script (requires PHP-CLI) for generating the `find`
  command and reading the results by `find` from STDIN generating the exclude
  list (to STDOUT) and the hard link restore list to (to file on disk).
* make_exclude.sh: Script gluing together `exclude_list.php`'s in-and output.
* make-oc-tsm-exclude-list-cron.job: Template to put in /etc/cron.d/ so the exclude list is
  generated every day.

## How did we use this software?

0. Take note of `/opt/tivoli/tsm/client/ba/bin/dsmsched.log`. If your backup run
   time is already close to 24h, you probably can't use an even larger exclude
   list because adding exclude entries will slow TSM's run.
1. Git clone (the `#` is because we did that a root user)
```
# cd /opt
# git clone https://github.com/Rillke/opencast-tsm-config.git
# cd opencast-tsm-config/exclude-hardlinks
```
2. Configure the scripts so the paths match
3. Preserve the current inclexcl.list
```
# cp -a /opt/tivoli/tsm/client/ba/bin/inclexcl.list /opt/tivoli/tsm/client/ba/bin/inclexcl.list.base
```
Hint you may want to exclude your Opencast workspace [temporary processing
artifacts from workflow processing] and maybe indices from backup. In case of an
emergency rebuilding indices might be better if you can't get a consistent copy
backed up.
Example for `/opt/tivoli/tsm/client/ba/bin/inclexcl.list.base`:
```
exclude         /.../core
exclude         /opt/tivoli/tsm/client/ba/bin/dsmsched.log
exclude.dir      /tmp
exclude.dir      /var/cache
exclude.dir      /var/tmp
exclude.dir      /var/lib/mysql
exclude          /var/lib/docker/.../*
include          /var/lib/docker/volumes/.../*
exclude.dir      /opt/nfsexport/opencast_prod/opencast/workspace
exclude.dir      /opt/nfsexport/opencast_prod/opencast/files
exclude.dir      /opt/nfsexport/opencast_prod/solr-indexes
exclude.dir      /opt/nfsexport/opencast_prod/index
```
Lars wrote about the `org.opencastproject.file.repo.path`:
> Daten im Working File Repository sollten eigentlich nur relevant sein
solange ein Workflow läuft. Da braucht also nichts in ein Backup.

4. Do a test run of the script and inspect the output files
```
# ./make_exclude.sh
# less /opt/tivoli/tsm/client/ba/bin/inclexcl.list
# less restore_links_*.sh
```
Your exclude list (`/opt/tivoli/tsm/client/ba/bin/inclexcl.list`) should look
like this (without the three dots [ellipsis] in the middle):
```
EXCLUDE "/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/1/deb24ae1-9424-4717-b3c4-XXXXXX.flv"
EXCLUDE "/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/2/deb24ae1-9424-4717-b3c4-XXXXXX.flv"
...
EXCLUDE "/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/6/deb24ae1-9424-4717-b3c4-XXXXXX.flv"
```
NOTE: There is never ever a `/0/` directory containing the original file.
Your restoration script (`restore_links_*.sh`) should look
like this (without the three dots [ellipsis] in the middle):
```
ln "/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/0/deb24ae1-9424-4717-b3c4-XXXXXX.flv" "/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/1/deb24ae1-9424-4717-b3c4-XXXXXX.flv"
ln "/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/0/deb24ae1-9424-4717-b3c4-XXXXXX.flv" "/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/2/deb24ae1-9424-4717-b3c4-XXXXXX.flv"
...
ln "/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/0/deb24ae1-9424-4717-b3c4-XXXXXX.flv" "/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/6/deb24ae1-9424-4717-b3c4-XXXXXX.flv"
```
5. Install the cron-script
```
# cp make-oc-tsm-exclude-list-cron.job /etc/cron.d
```
6. See what the `dsmc` (Distributed Storage Manager Client) says
```
# dsmc -query inclexcl
OR
# dsmc q inclexcl
```
7. Immediately test an incremental backup
```
# dsmc -incremental
OR
# dsmc i
```
8. Create a deletion list from the exclude list
```
sed -E 's/EXCLUDE "(.+)"'/\\1/ig inclexclude.lst > del_files.lst
```
Your deletion list should look like this (without the three dots [ellipsis] in the middle):
```
/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/1/deb24ae1-9424-4717-b3c4-XXXXXX.flv
/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/2/deb24ae1-9424-4717-b3c4-XXXXXX.flv
...
/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/264499b8-6509-4730-a146-XXXXXX/6/deb24ae1-9424-4717-b3c4-XXXXXX.flv
...
/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/47906140-6d4d-4756-8052-XXXXXX/4/7d409d37-6774-48ff-aaa6-XXXXXX.mp4
/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/47906140-6d4d-4756-8052-XXXXXX/5/7d409d37-6774-48ff-aaa6-XXXXXX.mp4
/opt/nfsexport/opencast_prod/opencast/archive/mh_default_org/47906140-6d4d-4756-8052-XXXXXX/6/7d409d37-6774-48ff-aaa6-XXXXXX.mp4
```
NOTE: There is never ever a `/0/` directory containing the original file.
9. Ask your backup admin to review the deletion list and the command and to
   allow deletion.
```
# nohup dsmc delete backup -deltype=inactive -filelist=/opt/opencast-tsm-config/exclude-hardlinks/del_files.lst &
```

## Caveats

* Make sure Opencast does not delete snapshots containing "original" files while
  creating new snapshots after the exclude list has been generated and before
  the "original" is backed up; otherwise you miss that file from that daily
  backup. In other words, none of your regular workflows should contain
  an asset-delete operation and asset-delete must not run between building the
  exclude list and backup's successful end.
* Large exclude lists can significantly slow the backup run.

## FAQ

### The slow-down is too heavy. TSM does not manage to do a full backup a day.

Your solution might be to keep only the latest version of a snaphot on disk
([`asset-delete`](../asset-delete) might help), or raise `$min_size_MB` in
`exclude_list.php`.
