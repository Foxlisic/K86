
        org     0

        mov     ax, cs
        mov     ss, ax
        mov     sp, 0x8000
        call    screen3
        mov     al, 0x17
        call    cls
        mov     si, t1
        call    fp_print
        jmp     $

t1:     dd 7.31223

; ----------------------------------------------------------------------
include "../../../include/screen.asm"
include "../../../include/math.asm"
