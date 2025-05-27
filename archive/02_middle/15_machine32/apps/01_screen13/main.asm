
        org     0

        ; Видеорежим 320 x 200 x 256
        mov     dx, 3d8h
        mov     al, 3
        out     dx, al

        ; Тестовый матрас
        mov     ax, $A000
        mov     es, ax
m1:     xor     di, di
        mov     bx, $C800
@@:     mov     al, bl
        add     al, bh
        add     al, cl
        stosb
        inc     bl
        jne     @b
        add     di, 320-256
        dec     bh
        jne     @b
        inc     cl
        jmp     m1
