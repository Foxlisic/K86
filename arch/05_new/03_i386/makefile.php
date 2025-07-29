<?php

$LIB = "/usr/share/verilator/include";
$INC = "$LIB/verilated.cpp $LIB/verilated_threads.cpp";
$OBJ = "obj_dir/Vcore__ALL.a";
$RUN = isset($argv[1]) && $argv[1] == 'run';

$touchfile = false;

$files = [
    'core.v'        => 'v',
    'i386.cc'       => 'c',
    'i386.cpp'      => 'c',
    'i386.h'        => 'c',
    'i386_dasm.cpp' => 'c',
];

// Ассемблировать файлы
$fasm = `fasm bios.asm bios.bin 2>&1`;
if (preg_match("~error:~", $fasm)) { die($fasm); }

// Перевести в HEX
$in = file_get_contents('bios.bin');
$out = []; for ($i = 0; $i < strlen($in); $i++) $out[] = sprintf("%02X", ord($in[$i]));
file_put_contents('i386.hex', join("\n", $out));

// Перевод в MIF (RLE-кодирование)
$size = 128*1024;
$in   = str_repeat(chr(0), 256) . $in;
$out  = ["WIDTH=8;", "DEPTH=$size;", "ADDRESS_RADIX=HEX;", "DATA_RADIX=HEX;", "CONTENT BEGIN"];
$len  = strlen($in);
$a    = 0;

while ($a < $len)
{
    for ($b = $a + 1; $b < $len && $in[$a] == $in[$b]; $b++);
    if ($b - $a < 3) {
        for ($i = $a; $i < $b; $i++) $out[] = sprintf("  %X: %02X;", $a++, ord($in[$i]));
    } else {
        $out[] = sprintf("  [%X..%X]: %02X;", $a, $b - 1, ord($in[$a]));
        $a = $b;
    }
}

if ($len < $size) $out[] = sprintf("  [%X..%X]: 00;", $len, $size-1); $out[] = "END;";
file_put_contents("de0/mem_common.mif", join("\n", $out));

// Отыкарусить
echo `iverilog -g2005-sv -o i386.qqq i386.v core.v`;
echo `vvp i386.qqq -o i386.vcd > /dev/null`;

if (file_exists('i386.qqq')) {
    unlink('i386.qqq');
} else {
    exit;
}

// -----------------------------------------------------------------------------
// Компиляция Verilator, GCC
// -----------------------------------------------------------------------------

if ($RUN)
{
    if (!file_exists(".tmp")) mkdir(".tmp");

    // Скомпилировать, если надо)
    foreach ($files as $file => $type)
    {
        $tf = ".tmp/.$file";
        $ts = file_exists($tf) ? file_get_contents($tf) : 0;
        $mt = filemtime($file);

        if ($mt != $ts)
        {
            if ($type == 'v')
            {
                $time = time();
                `verilator --threads 1 -cc core.v`;
                `cd obj_dir && make -f Vcore.mk`;
                echo "[".(time() - $time)."] $file\n";
            }

            $touchfile = true;
        }

        file_put_contents($tf, $mt);
    }

    // Требуется перекомпиляция
    if ($touchfile)
    {
        $time = time();
        `g++ -Ofast -Wno-unused-result -o i386 -I$LIB i386.cc $INC $OBJ -lSDL2`;
        echo "[".(time() - $time)."] GCC\n";
    }

    // Запуск программы -d
    echo `./i386 bios.bin > i386.log`;
}
