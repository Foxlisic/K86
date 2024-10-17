
        include "app/macro.asm"
        org     100h

        screen  13

        mov     ax, $B000
        mov     es, ax
        xor     di, di

        ; LINE
        mov     al, 1
        stosb
        mov     ax, 16
        stosw
        mov     ax, 2
        stosw
        mov     ax, 318
        stosw
        mov     ax, 198
        stosw
        mov     al, 15
        stosb
        mov     al, 0       ; EOF
        stosb

        mov     dx, $300
        out     dx, al
        hlt
