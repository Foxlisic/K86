<?php

$in = file_get_contents($argv[1] ?? "boot.bin");
$fs = strlen($in);

$out = [];
for ($i = 0; $i < $fs; $i++) {
    $out[] = sprintf("%02X", ord($in[$i]));
}

file_put_contents($argv[2] ?? "boot.hex", join("\n", $out));
