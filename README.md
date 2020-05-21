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

## Helpers available in this repo

* [`/exclude-hardlinks`](./exclude-hardlinks): Exclude hardlinks pointing to the
  same inode from TSM backup.
* [`/asset-delete`](./asset-delete): Delete snapshots from Opencast given
  criteria.

## Tested with

### setting 1

* Ubuntu 18.04.4 LTS (GNU/Linux 4.15.0-91-generic x86_64)
* IBM Spectrum Protect-Client für Sichern/Archivieren Version 8, Release 1, Stufe 4.0
* Opencast 7.7
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

Some days after adding copies as excludes (`/exclude-hardlinks`) to
inclexcl.list:
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

Some days after deleting old snapshots (`/asset-delete`, while keeping recently
  changed snapshots, and preventing duplicates using inclexcl.list):

* |inclexcl.list| = 7033

```
Gesamtzahl überprüfter Objekte:                     1.481.262
Gesamtzahl gesicherter Objekte:                         9.195
Gesamtzahl aktualisierter Objekte:                          0
Gesamtzahl erneut gebundener Objekte:                       0
Gesamtzahl gelöschter Objekte:                              0
Gesamtzahl verfallener Objekte:                           608
Gesamtzahl fehlgeschlagener Objekte:                        0
Gesamtzahl verschlüsselter Objekte:                         0
Gesamtzahl vergrößerter Objekte:                            0
Gesamtzahl Wiederholungen:                                  0
Gesamtzahl überprüfter Byte:                            25,94 TB
Gesamtzahl übertragener Byte:                          421,57 GB
Datenübertragungszeit:                               3.036,50 Sek.
Datenübertragungsgeschwindigkeit im Netz:          145.579,79 KB/Sek
Datenübertragungsgeschwindigkeit für Aggregat:      51.711,10 KB/Sek
Objekte komprimiert um:                                     0 %
Gesamtverhältnis der Datenreduktion:                    98,42 %
Abgelaufene Verarbeitungszeit:                       02:22:28
```
