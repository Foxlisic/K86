
            cli

            ; +64k
            mov     ax, cs
            add     ax, 1000h
            mov     ds, ax
            mov     es, ax
            mov     ss, ax

            xor     di, di
            xor     ax, ax
            mov     cx, 256
            rep     stosb

            mov     [cs:cursor], word 0
            mov     sp, 256

            ; Очистить регистры
            xor     ax, ax
            xor     bx, bx
            xor     cx, cx
            xor     dx, dx
            xor     bp, bp
            xor     si, si
            xor     di, di
