; Простая 16-битная операционная система для эмулятора

        mov     ax, $0013
        int     10h

        ; Проставление цветовой схемы
        mov     ax, 0
        mov     cx, 64
        mov     dx, $3c8
@@:     mov     al, ah
        out     dx, al
        inc     dx
        mov     al, 0
        out     dx, al
        mov     al, ah
        out     dx, al
        mov     al, 0
        out     dx, al
        inc     ah
        dec     dx
        loop    @b

        mov     ax, $a000
        mov     es, ax
        xor     di, di

        mov     cx, 200
.a:     push    cx
        mov     cx, 256
@@:     stosb
        inc     al
        loop    @b
        add     di, 320 - 256
        pop     cx
        loop    .a

        hlt
        jmp     $
