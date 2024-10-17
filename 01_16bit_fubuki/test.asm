
        include "app/macro.asm"
        org     100h

        screen  13

        mov     ax, $C000
        mov     es, ax
        xor     di, di

        ; LINE
        mov     al, 2
        stosb
        mov     ax, 1       ; x1
        stosw
        mov     ax, 1       ; y1
        stosw
        mov     ax, 318     ; x2
        stosw
        mov     ax, 198     ; y2
        stosw
        mov     al, 14
        stosb
        mov     al, 0       ; EOF
        stosb

        mov     dx, $300
        out     dx, al
        hlt
