<?php

class x86 {

    public $x86_table = [
        'ADD      |rm,r8      |m| |',
        'ADD      |rm,r16     |m| |',
        'ADD      |r8,rm      |m| |',
        'ADD      |r16,rm     |m| |',
        'ADD      |al,i8      | |1|',
        'ADD      |ax,i16     | |2|',
        'PUSH     |es         | | |',
        'POP      |es         | | |',
        'OR       |rm,r8      |m| |',
        'OR       |rm,r16     |m| |',
        'OR       |r8,rm      |m| |',
        'OR       |r16,rm     |m| |',
        'OR       |al,i8      | |1|',
        'OR       |ax,i16     | |2|',
        'PUSH     |cs         | | |',
        '*        |           |p| |',
        'ADC      |rm,r8      |m| |',
        'ADC      |rm,r16     |m| |',
        'ADC      |r8,rm      |m| |',
        'ADC      |r16,rm     |m| |',
        'ADC      |al,i8      | |1|',
        'ADC      |ax,i16     | |2|',
        'PUSH     |ss         | | |',
        'POP      |ss         | | |',
        'SBB      |rm,r8      |m| |',
        'SBB      |rm,r16     |m| |',
        'SBB      |r8,rm      |m| |',
        'SBB      |r16,rm     |m| |',
        'SBB      |al,i8      | |1|',
        'SBB      |ax,i16     | |2|',
        'PUSH     |ds         | | |',
        'POP      |ds         | | |',
        'AND      |rm,r8      |m| |',
        'AND      |rm,r16     |m| |',
        'AND      |r8,rm      |m| |',
        'AND      |r16,rm     |m| |',
        'AND      |al,i8      | |1|',
        'AND      |ax,i16     | |2|',
        'ES:      |           |p| |',
        'DAA      |           | | |',
        'SUB      |rm,r8      |m| |',
        'SUB      |rm,r16     |m| |',
        'SUB      |r8,rm      |m| |',
        'SUB      |r16,rm     |m| |',
        'SUB      |al,i8      | |1|',
        'SUB      |ax,i16     | |2|',
        'CS:      |           |p| |',
        'DAS      |           | | |',
        'XOR      |rm,r8      |m| |',
        'XOR      |rm,r16     |m| |',
        'XOR      |r8,rm      |m| |',
        'XOR      |r16,rm     |m| |',
        'XOR      |al,i8      | |1|',
        'XOR      |ax,i16     | |2|',
        'SS:      |           |p| |',
        'AAA      |           | | |',
        'CMP      |rm,r8      |m| |',
        'CMP      |rm,r16     |m| |',
        'CMP      |r8,rm      |m| |',
        'CMP      |r16,rm     |m| |',
        'CMP      |al,i8      | |1|',
        'CMP      |ax,i16     | |2|',
        'DS:      |           |p| |',
        'AAS      |           | | |',
        'INC      |ax         | | |',
        'INC      |cx         | | |',
        'INC      |dx         | | |',
        'INC      |bx         | | |',
        'INC      |sp         | | |',
        'INC      |bp         | | |',
        'INC      |si         | | |',
        'INC      |di         | | |',
        'DEC      |ax         | | |',
        'DEC      |cx         | | |',
        'DEC      |dx         | | |',
        'DEC      |bx         | | |',
        'DEC      |sp         | | |',
        'DEC      |bp         | | |',
        'DEC      |si         | | |',
        'DEC      |di         | | |',
        'PUSH     |ax         | | |',
        'PUSH     |cx         | | |',
        'PUSH     |dx         | | |',
        'PUSH     |bx         | | |',
        'PUSH     |sp         | | |',
        'PUSH     |bp         | | |',
        'PUSH     |si         | | |',
        'PUSH     |di         | | |',
        'POP      |ax         | | |',
        'POP      |cx         | | |',
        'POP      |dx         | | |',
        'POP      |bx         | | |',
        'POP      |sp         | | |',
        'POP      |bp         | | |',
        'POP      |si         | | |',
        'POP      |di         | | |',
        'PUSHA    |           | | |',
        'POPA     |           | | |',
        'BOUND    |r16,m      |m| |',
        'ARPL     |rm,r16     |m| |',
        'FS:      |           |p| |',
        'GS:      |           |p| |',
        'Opsz     |           |p| |',
        'Rgsz     |           |p| |',
        'PUSH     |i16        | |2|',
        'IMUL     |r16,rm,i16 |m|2|',
        'PUSH     |i8         | |1|',
        'IMUL     |r16,rm,i8  |m|1|',
        'INSB     |           | | |',
        'INSW     |           | | |',
        'OUTSB    |           | | |',
        'OUTSW    |           | | |',
        'JO       |b8         | |1|',
        'JNO      |b8         | |1|',
        'JB       |b8         | |1|',
        'JNB      |b8         | |1|',
        'JE       |b8         | |1|',
        'JNE      |b8         | |1|',
        'JBE      |b8         | |1|',
        'JA       |b8         | |1|',
        'JS       |b8         | |1|',
        'JNS      |b8         | |1|',
        'JP       |b8         | |1|',
        'JNP      |b8         | |1|',
        'JL       |b8         | |1|',
        'JNL      |b8         | |1|',
        'JLE      |b8         | |1|',
        'JG       |b8         | |1|',
        'GRP1     |rm,i8      |g|1|',
        'GRP1     |rm,i16     |g|2|',
        'GRP1     |rm8,i8     |g|1|',
        'GRP1     |rm16,i8    |g|1|',
        'TEST     |rm,r8      |m| |',
        'TEST     |rm,r16     |m| |',
        'XCHG     |r8,rm      |m| |',
        'XCHG     |r16,rm     |m| |',
        'MOV      |rm,r8      |m| |',
        'MOV      |rm,r16     |m| |',
        'MOV      |r8,rm      |m| |',
        'MOV      |r16,rm     |m| |',
        'MOV      |rm16,sreg  |m| |',
        'LEA      |r16,rm     |m| |',
        'MOV      |sreg,rm16  |m| |',
        'POP      |rm16       |m| |',
        'NOP      |           | | |',
        'XCHG     |ax,cx      | | |',
        'XCHG     |ax,dx      | | |',
        'XCHG     |ax,bx      | | |',
        'XCHG     |ax,sp      | | |',
        'XCHG     |ax,bp      | | |',
        'XCHG     |ax,si      | | |',
        'XCHG     |ax,di      | | |',
        'CBW      |           | | |',
        'CWD      |           | | |',
        'CALL     |p16:16     | |4|',
        'FWAIT    |           | | |',
        'PUSHF    |           | | |',
        'POPF     |           | | |',
        'SAHF     |           | | |',
        'LAHF     |           | | |',
        'MOV      |al,[m]     | |2|',
        'MOV      |ax,[m]     | |2|',
        'MOV      |[m],al     | |2|',
        'MOV      |[m],ax     | |2|',
        'MOVSB    |           | | |',
        'MOVSW    |           | | |',
        'CMPSB    |           | | |',
        'CMPSW    |           | | |',
        'TEST     |al,i8      | |1|',
        'TEST     |ax,i16     | |2|',
        'STOSB    |           | | |',
        'STOSW    |           | | |',
        'LODSB    |           | | |',
        'LODSW    |           | | |',
        'SCASB    |           | | |',
        'SCASW    |           | | |',
        'MOV      |al,i8      | |1|',
        'MOV      |cl,i8      | |1|',
        'MOV      |dl,i8      | |1|',
        'MOV      |bl,i8      | |1|',
        'MOV      |ah,i8      | |1|',
        'MOV      |ch,i8      | |1|',
        'MOV      |dh,i8      | |1|',
        'MOV      |bh,i8      | |1|',
        'MOV      |ax,i16     | |2|',
        'MOV      |cx,i16     | |2|',
        'MOV      |dx,i16     | |2|',
        'MOV      |bx,i16     | |2|',
        'MOV      |sp,i16     | |2|',
        'MOV      |bp,i16     | |2|',
        'MOV      |si,i16     | |2|',
        'MOV      |di,i16     | |2|',
        'GRP2     |rm8,i8     |g|1|',
        'GRP2     |rm16,i8    |g|1|',
        'RET      |i16        | |2|',
        'RET      |           | | |',
        'LES      |r16,[m]    |m| |',
        'LDS      |r16,[m]    |m| |',
        'MOV      |rm8,i8     |m|1|',
        'MOV      |rm16,i16   |m|2|',
        'ENTER    |i16,i8     | |3|',
        'LEAVE    |           | | |',
        'RETF     |i16        | |2|',
        'RETF     |           | | |',
        'INT      |3          | | |',
        'INT      |i8         | |1|',
        'INTO     |           | | |',
        'IRET     |           | | |',
        'GRP2     |rm8,1      |g| |',
        'GRP2     |rm16,1     |g| |',
        'GRP2     |rm8,cl     |g| |',
        'GRP2     |rm16,cl    |g| |',
        'AAM      |           | |1|',
        'AAD      |           | |1|',
        'SALC     |           | | |',
        'XLATB    |           | | |',
        'FPU0     |           |g| |',
        'FPU1     |           |g| |',
        'FPU2     |           |g| |',
        'FPU3     |           |g| |',
        'FPU4     |           |g| |',
        'FPU5     |           |g| |',
        'FPU6     |           |g| |',
        'FPU7     |           |g| |',
        'LOOPNZ   |b8         | |1|',
        'LOOPZ    |b8         | |1|',
        'LOOP     |b8         | |1|',
        'JCXZ     |b8         | |1|',
        'IN       |al,i8      | |1|',
        'IN       |ax,i8      | |1|',
        'OUT      |i8,al      | |1|',
        'OUT      |i8,ax      | |1|',
        'CALL     |b16        | |2|',
        'JMP      |b16        | |2|',
        'JMP      |p16:16     | |4|',
        'JMP      |b8         | |1|',
        'IN       |al,dx      | | |',
        'IN       |ax,dx      | | |',
        'OUT      |dx,al      | | |',
        'OUT      |dx,ax      | | |',
        'LOCK:    |           |p| |',
        'INT      |1          | | |',
        'REPNZ:   |           |p| |',
        'REPZ:    |           |p| |',
        'HLT      |           | | |',
        'CMC      |           | | |',
        'GRP3     |8*         |g|1|',
        'GRP3     |16*        |g|2|',
        'CLC      |           | | |',
        'STC      |           | | |',
        'CLI      |           | | |',
        'STI      |           | | |',
        'CLD      |           | | |',
        'STD      |           | | |',
        'GRP4     |8*         |g| |',
        'GRP4     |16*        |g| |',
    ];

    public $x86_group = [
        'R8'    => ['al','cl','dl','bl','ah','ch','dh','bh'],
        'R16'   => ['ax','cx','dx','bx','sp','bp','si','di'],
        'SEG'   => ['es','cs','ss','ds','fs','gs','?','?'],
        'GRP1'  => ['add','or','adc','sbb','and','sub','xor','cmp'],
        'GRP2'  => ['rol','ror','rcl','rcr','shl','shr','sal','sar'],
        'GRP3'  => ['test','test','not','neg','mul','imul','div','idiv'],
        'GRP4'  => ['inc','dec','call','callf','jmp','jmpf','push','?'],
    ];

    public $x86_rm = [
        ['[bx+si]','[bx+si+d8]','[bx+si+d16]','al|ax|es'],
        ['[bx+di]','[bx+di+d8]','[bx+di+d16]','cl|cx|cs'],
        ['[bp+si]','[bp+si+d8]','[bp+si+d16]','dl|dx|ss'],
        ['[bp+di]','[bp+di+d8]','[bp+di+d16]','bl|bx|ds'],
        ['[si]',   '[si+d8]',   '[si+d16]',   'ah|sp|fs'],
        ['[di]',   '[di+d8]',   '[di+d16]',   'ch|bp|gs'],
        ['[d16]',  '[bp+d8]',   '[bp+d16]',   'dh|si'],
        ['[bx]',   '[bx+d8]',   '[bx+d16]',   'bh|di'],
    ];

    // [Выход] Список инструкции
    public function generate()
    {
        $map = $this->parse_x86_table();

        // Рендеринг инструкции
        $htm = '<table class="x86-table" width="100%">'."\n";
        foreach ($map as $n => $item) {

            $row = "<tr>\n";
            foreach ($item as $a => $b) {

                $x  = $n*16 + $a;
                $y  = sprintf("%02X", $x);
                $m0 = trim($b[0]);
                $m1 = trim($b[1]);
                $m2 = trim($b[2]) ? $b[2] : "o";

                $curx = sprintf("%02X", $x);
                $row .= "    <!--$curx--><td class='x86 x86-$m2'><div><span>$y</span><b>$m0</b></div>$m1</td>\n";
            }

            $htm .= "$row";
            $htm .= "</tr>\n";
        }

        $htm .= "</table>\n";
        $htm .= "<b>ГРУППЫ</b>\n";
        $htm .= "<table>\n";
        $htm .= '<tr><th style="width:50px">GROUP</th>'; for ($i = 0; $i < 8; $i++) { $htm .= "<th>$i</th>"; } $htm .= "</tr>\n";

        // Рендеринг групп
        foreach ($this->x86_group as $name => $grp) {

            $htm .= "<tr>\n";
            $htm .= "    <th>".strtoupper($name)."</th>\n";
            foreach ($grp as $item) {
                $htm .= "    <td>".strtoupper($item)."</td>\n";
            }
            $htm .= "</tr>\n";
        }

        $htm .= '</table>';

        return $htm;
    }

    // Парсер данных
    public function parse_x86_table() {

        $map = [];
        foreach (array_map('rtrim', $this->x86_table) as $code => $row) {
            $map[$code>>4][$code & 15] = array_map('trim', explode('|', $row));
        }
        return $map;
    }
}

?>
<!doctype html>
<html>
<head>
    <meta charset="utf8">
    <title>8086 INSTRUCTION SET TABLE DONE</title>
    <style>
        body, html { padding: 0; margin: 0; }
        table { border-collapse: collapse; }
        tr { vertical-align: top; }
        td, th { background: #ffe; padding: 3px; border: 1px solid #999; font-size: 11px; font-family: Monospace; line-height: 1.3em; letter-spacing: -1px; }
        td b { display: block; text-decoration: underline;  }
        th { width: 30px; background: #ffa; }
        .x86-table td { width: 6%; }
        td.x86 { opacity: 1.0; }
        td.done { opacity: 1.0; }
        td.x86-o { background: #ffa; }
        td.x86-m { background: #cfc; }
        td.x86-g { background: #cac; }
        td.x86-p { background: #aee; }
        td.x86-e { background: #efe; }
        td span { float: right; }
    </style>
</head>
<body>
<?=(new x86())->generate();?>
</body>
</html>
