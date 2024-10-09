
        org     100h

        cli                         ; Стандартный сброс
        mov     ax, 03h
        int     10h

        xor     ax, ax
        mov     ss, ax
        mov     ds, ax              ; DS=CS
        mov     ax, $B800           ; A000 или B800
        mov     es, ax

        ;xor     di, di
        ;mov     cx, 64000
@@:     ;stosb
        ;inc     al
        ;loop    @b
        ;hlt

        ; Кошатина
        xor     di, di
        mov     ah, $07
        mov     cx, 667
@@:     mov     al, 'o'
        stosw
        mov     al, 'O'
        stosw
        stosw
        loop    @b

        hlt
