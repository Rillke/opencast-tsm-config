#!/usr/bin/php
<?php

//--- parameters ---
$basepath = "/opt/nfsexport/opencast_prod/opencast/archive";
$min_size_MB = 10;

$cmd = "find \"" . $basepath . "\" -links +1 -size +" . $min_size_MB . "M  -printf \"%i %p \\n\"";
$filename_ln = "restore_links_" . date("Y-m-d_h-i-s") . ".sh";

//--- print search command to be executed by a shell ($cmd | sh ) ---
if ($argc == 2) if ($argv[1] === "-c") echo $cmd . "\n";

//--- groups file by inode (PIPE IN) ---
$uniq = [];
$lnk = [];

if ($argc == 2) if ($argv[1] === "-")
{
    while (!feof(STDIN))
    {
        $line = fgets(STDIN);
        if (preg_match("/(\d*) (.*)/", $line, $match))
        {
            $inode = $match[1];
            // assumption: the file name does not begin or end with white space
            $path = trim($match[2]);
            if (isset($uniq[$inode]))
            {
                // found a hard link
                echo "EXCLUDE " . "\"" . $path . "\"" . "\n";
                $lnk[] = "ln " . "\"" . $uniq[$inode][0] . "\"" . " " . "\"" . $path . "\"";
            }
            else
            {
                // assume this file to be the "original", collect the path
                $uniq[$inode][] = $path;
            }
        }
    }
    // write out file required for restoring symlinks
    file_put_contents($filename_ln, implode($lnk, "\n"));
}
