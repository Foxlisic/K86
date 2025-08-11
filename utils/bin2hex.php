<?php

$bin = file_get_contents($argv[1]);
$hex = [];
for ($i = 0; $i < strlen($bin); $i++) {
    $hex[] = sprintf("%02X", ord($bin[$i]));
}
file_put_contents($argv[2], join("\n", $hex));
