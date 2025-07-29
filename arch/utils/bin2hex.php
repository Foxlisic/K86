<?php

$bin = file_get_contents($argv[1]);
for ($i = 0; $i < strlen($bin); $i++)
    echo sprintf("%02x\n", ord($bin[$i]));
