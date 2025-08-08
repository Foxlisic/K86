include "../macro.asm"
; ------------------------------------------------------------------------------
        org     100h
; ------------------------------------------------------------------------------
start:
        screen  13

        ; ------------------------

        mov     ah, 0
        xor     bx, bx
        xor     cx, cx
        mov     cl, 4
@@:     call    pal
        inc     ah
        add     ch, 16
        dec     cl
        jne     @b

        mov     cl, 64
        mov     ch, 63
@@:     call    pal
        inc     ah
        dec     ch
        inc     bh
        dec     cl
        jne     @b

        mov     cl, 64
        mov     ch, 0
        mov     bh, 63
@@:     call    pal
        inc     ah
        inc     bl
        dec     cl
        jne     @b

        mov     cl, 64
        mov     bl, 63
@@:     call    pal
        inc     ah
        inc     ch
        dec     cl
        jne     @b

        ; ------------------------

        mov     ax, es
        mov     ds, ax
        xor     bx, bx

        ; Итератор
r1:     mov     di, 16000
        mov     cx, 48000-320
r2:     mov     ah, 0
        mov     al, [di]
        add     al, [di+319]
        adc     ah, 0
        add     al, [di+320]
        adc     ah, 0
        add     al, [di+321]
        adc     ah, 0
        dec     ax
        jns     r3
        mov     ax, 0
r3:     shr     ax, 2
        stosb
        loop    r2

        ; Генератор
        mov     cx, 320
r4:     imul    ax, 2345
        add     ax, bx
        add     bx, 3
        stosb
        loop    r4
        jmp     r1

pal:    palette ah, bh, bl, ch
        ret
        hlt
