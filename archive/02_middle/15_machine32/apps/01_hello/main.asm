
        org     0

        mov     ax, $B800
        mov     es, ax
        xor     di, di
        mov     cx, 2000
        mov     ax, $083a
        rep     stosw
        jmp     $
