# Opencast TSM Backup Configuration

Important note: You are solely responsible for any actions towards your backup.
Although we haven't intentionally put any mistakes here, you should triple-check
the scripts before execution. Ask you backup admin for help and review.

[Opencast](https://opencast.org/) is a free, open-source software for automated
video capture, processing, managing, and distribution. Opencast is built by a
community of developers in collaboration with leading universities and
organizations worldwide.

IBM Spectrum Protect (IBM Tivoli Storage Manager [TSM]) is a data protection
platform that gives enterprises a single point of control and administration for
backup and recovery.

## Rationale

Opencast manages an archive of video files and their meta data, so called
"media packages". Each time meta data changes, or when explicitly triggered
during workflow processing, Opencast creates a new snapshot.

For each snapshot Opencast creates a sub directory, starting with /0, the next
snapshot operation would create /1.
Snapshots create a revision history of each media package. Each sub directory
contains the complete media package contents at a time. In order to achieve
completeness without copying identical data, Opencast makes use of hard links:
Identical files from previous media packages are hardlinked to any new snapshot.
Now you can, in theory, delete any previous version of the media package without
loosing data in the current snapshot. You can also take one snapshot (i.e. one
subdirectory) and this is a full media package without having to resolve any
dependency within Opencast's directory structure. If Opencast would use
synmlinks, or a database to store references, this wouldn't be that easy.

IBM Tivoli Storage Manager, on the other hand, does not handle hard links well.
Instead of storing references to an inode, like Opencast, it will duplicate
files sharing one inode on tape or whatever storage medium it uses.

This leads to a backup with about 25-times the size of the data stored on disk.

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
* opencast-cron.job: Template to put in /etc/cron.d/ so the exclude list is
  generated every day.

## How did we use this software?

0. Take note of `/opt/tivoli/tsm/client/ba/bin/dsmsched.log`. If your backup run
   time is already close to 24h, you probably can't use an even larger exclude
   list because adding exclude entries will slow TSM's run.
1. Git clone
```
# cd /opt
# git clone https://github.com/Rillke/opencast-tsm-config.git
# cd opencast-tsm-config
```
2. Configure the scripts so the paths match
3. Preserve the current inclexcl.list
```
# cp -a /opt/tivoli/tsm/client/ba/bin/inclexcl.list /opt/tivoli/tsm/client/ba/bin/inclexcl.list.base
```
Hint you may want to exclude your Opencast workspace from backup.
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
```
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
# cp opencast-cron.job /etc/cron.d
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
# nohup dsmc delete backup -deltype=inactive -filelist=/opt/opencast-tsm-config/del_files.lst &
```

## Caveats

* Make sure Opencast does not delete snapshots containing "original" files while
  creating new snapshots after the exclude list has been generated and before
  the "original" is backed up; otherwise you miss that file from that daily
  backup.
* Large exclude lists can significantly slow the backup run.

## FAQ

### The slow-down is too heavy. TSM does not manage to do a full backup a day.

Your solution might be to keep only the latest version of a snaphot on disk, or
raise `$min_size_MB` in `exclude_list.php`.

## Tested with

### setting 1

* Ubuntu 18.04.4 LTS (GNU/Linux 4.15.0-91-generic x86_64)
* IBM Spectrum Protect-Client für Sichern/Archivieren Version 8, Release 1, Stufe 4.0
* Opencast 7.6
* |inclexcl.list| = 87016
* Time to generate exclude list: roughly 2 min

Some days before adding copies as excludes to inclexcl.list:
```
Gesamtzahl überprüfter Objekte:                     2.641.823
Gesamtzahl gesicherter Objekte:                        13.120
Gesamtzahl aktualisierter Objekte:                         64
Gesamtzahl erneut gebundener Objekte:                       0
Gesamtzahl gelöschter Objekte:                              0
Gesamtzahl verfallener Objekte:                         5.421
Gesamtzahl fehlgeschlagener Objekte:                        0
Gesamtzahl verschlüsselter Objekte:                         0
Gesamtzahl vergrößerter Objekte:                            0
Gesamtzahl Wiederholungen:                                  0
Gesamtzahl überprüfter Byte:                           112,18 TB
Gesamtzahl übertragener Byte:                            1,25 TB
Datenübertragungszeit:                               8.341,80 Sek.
Datenübertragungsgeschwindigkeit im Netz:          161.057,04 KB/Sek
Datenübertragungsgeschwindigkeit für Aggregat:      81.436,42 KB/Sek
Objekte komprimiert um:                                     0 %
Gesamtverhältnis der Datenreduktion:                    98,89 %
Abgelaufene Verarbeitungszeit:                       04:34:57
```

Some days after adding copies as excludes to inclexcl.list:
```
Gesamtzahl überprüfter Objekte:                     2.554.907
Gesamtzahl gesicherter Objekte:                        18.656
Gesamtzahl aktualisierter Objekte:                         19
Gesamtzahl erneut gebundener Objekte:                       0
Gesamtzahl gelöschter Objekte:                              0
Gesamtzahl verfallener Objekte:                         1.863
Gesamtzahl fehlgeschlagener Objekte:                        8
Gesamtzahl verschlüsselter Objekte:                         0
Gesamtzahl vergrößerter Objekte:                            0
Gesamtzahl Wiederholungen:                                  3
Gesamtzahl überprüfter Byte:                           116,55 TB
Gesamtzahl übertragener Byte:                          336,22 GB
Datenübertragungszeit:                               1.748,89 Sek.
Datenübertragungsgeschwindigkeit im Netz:          201.587,05 KB/Sek
Datenübertragungsgeschwindigkeit für Aggregat:       7.342,33 KB/Sek
Objekte komprimiert um:                                     0 %
Gesamtverhältnis der Datenreduktion:                    99,72 %
Abgelaufene Verarbeitungszeit:                       13:20:16
```
