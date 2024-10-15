include "../macro.asm"

        org     100h
        screen  13

        mov     ax, es
        mov     ds, ax      ; Мяу
        mov     bx, 256
.x:     mov     ax, 0
        mov     di, 318
        mov     cx, 200
@@:     mov     al, ah
        stosw
        add     di, 317
        add     ax, bx
        inc     di
        loop    @b
        inc     bx
        call    move
        jmp     .x

        ; Скроллер
move:   xor     di, di
        mov     si, 2
        mov     dx, 200
@@:     mov     cx, (318/2)
        rep     movsw
        add     di, 2
        add     si, 2
        dec     dx
        jne     @b
        ret
