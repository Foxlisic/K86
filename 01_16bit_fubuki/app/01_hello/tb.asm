
        org     100h
include "../macro.asm"

        cli                         ; Стандартный сброс
        screen13

.a:     xor     di, di
        mov     ax, bx
        mov     cx, $C800
@@:     stosb
        inc     al
        dec     cl
        jnz     @b
        inc     al
        add     di, (320-256)
        dec     ch
        jnz     @b
        inc     bx
        jmp     .a

