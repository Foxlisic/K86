<?php

$in  = file_get_contents($argv[1] ?? "tb.bin");
$out = [];

for ($i = 0; $i < strlen($in); $i++) {
    $out[] = sprintf("%02X", ord($in[$i]));
}

file_put_contents($argv[2] ?? "tb.hex", join("\n", $out));
