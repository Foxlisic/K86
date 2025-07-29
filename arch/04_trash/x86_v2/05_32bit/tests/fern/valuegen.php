<?php

$array = [
"matrix0" => [
    // nextx = 0
    // nexty = .16 * y
    [0, 0,    0],
    [0, 0.16, 0]
],
"matrix1" => [
    // nextx = .2 * x - .26 * y
    // nexty = .23 * x + .22 * y + 1.6
    [0.2,  -0.26,   0],
    [0.23,  0.22, 1.6]
],
"matrix2" => [
    // nextx = -.15 * x + .28 * y
    // nexty = .26 * x + .24 * y + .44
    [-0.15, 0.28,    0],
    [ 0.26, 0.24, 0.44],
],
"matrix3" => [
    // nextx = .85 * x + .04 * y
    // nexty = -.04 * x + .85 * y + 1.6
    [ 0.85, 0.04,   0],
    [-0.04, 0.85, 1.6],
]
];

$precise = 0x800; // 11

foreach ($array as $name => $item) {

    echo "$name:\n";
    foreach ($item as $row) {

        foreach ($row as $i => $v) $row[$i] = '0x'.substr(sprintf("%04x", $v*$precise), -4);
        $str = join(", ", $row);
        echo "    dw $str\n";
    }

}
