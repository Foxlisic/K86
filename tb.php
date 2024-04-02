<?php

$r = [];
$b = file_get_contents($argv[1]);
for ($i = 0; $i < strlen($b); $i++) $r[] = sprintf("%02X", ord($b[$i]));
file_put_contents($argv[2], join("\n", $r));
