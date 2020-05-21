#!/usr/bin/env bash
cd  "$(dirname """$0""")" || exit

rm  restore_links_*.sh.gz 2> /dev/null

#./exclude_list.php -c | sh 2>/dev/null | sort | ./exclude_list.php - > inclexclude.lst

# sortiere kann weggelassen werden - find folgt iterierung des Dateisystems, die kann als stabil angenommen werden (siehe "ls -f")
./exclude_list.php -c | sh 2>/dev/null | ./exclude_list.php - > inclexclude.lst

/bin/gzip  restore_links_*.sh > /dev/null

cat /opt/tivoli/tsm/client/ba/bin/inclexcl.list.base /opt/opencast-tsm-config/exclude-hardlinks/inclexclude.lst > /opt/tivoli/tsm/client/ba/bin/inclexcl.list
