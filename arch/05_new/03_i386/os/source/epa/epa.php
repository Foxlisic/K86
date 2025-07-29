<?php

$im = imagecreatefrompng("es.png");

for ($y = 0; $y < imagesy($im); $y++)
for ($x = 0; $x < imagesx($im); $x++) {

    $c = imagecolorat($im, $x, $y);
    $block[($x>>3) + (imagesx($im)/8)*($y>>4)][] = $c;
}

foreach ($block as $u => $m) {
    $block[$u] = join($m);
    $hash[$block[$u]] = $u;
}

print_r($hash);
echo "=".count($hash)."\n";