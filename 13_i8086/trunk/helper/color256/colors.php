<?php 

$im = imagecreatefrompng("gradient.png");

$id = 0;
echo "dac256[256] = {\n";
for ($x = 1; $x < 256*2; $x += 2) {
    
    $c = imagecolorat($im, $x, 100);
    //echo dechex($c) . "\n";
    
    echo sprintf("/* %02x */ 0x%06x,\n", $id++, $c);
}
echo "};";
