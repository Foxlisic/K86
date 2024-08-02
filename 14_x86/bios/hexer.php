<?php

    $bin = file_get_contents($argv[1]);
    for ($i = 0; $i < strlen($bin); $i++) {
        echo str_pad(dechex(ord($bin[$i])), 2, '0', STR_PAD_LEFT) . "\n";
    }

?>
