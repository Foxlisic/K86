<?php

$in = file_get_contents($argv[1]);
$out = [];
for ($i = 0; $i < strlen($in); $i++) {
    $out[] = sprintf("%02X", ord($in[$i]));
}
file_put_contents($argv[2], join("\n", $out));
