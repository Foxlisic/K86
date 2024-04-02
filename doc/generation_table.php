<?php

echo "<table>\n";
for ($i = 0; $i < 16; $i++) {

    echo "<!--".strtoupper(dechex($i))."x-->\n<tr>\n";
    for ($j = 0; $j < 16; $j++) {
        echo "    <!--".strtoupper(dechex($i).dechex($j))."--><td><b></b></td>\n";
    }
    echo "</tr>\n";
}
echo "</table>";
