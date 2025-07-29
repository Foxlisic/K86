; ----------------------------------------------------------------------
cls:    push    es
        push    word $b800
        pop     es
        xor     di, di          ; Очистка экрана
        mov     cx, 80*25
        rep     stosw
        pop     es
@@:     ret
print:  lodsb                   ; Напечатать строку
        and     al, al
        je      @b
        mov     ah, 0eh
        int     10h
        jmp     print
hex4:   cld
        mov     ah, al          ; Выдать 4 бита
        and     al, $0F
        cmp     al, 10
        jb      @f
        add     al, 7
@@:     add     al, '0'
        mov     ah, 0eh
        int     10h
        inc     di
        mov     al, ah
        ret
hex8:   push    ax
        ror     al, 4           ; Выдать 8 бит
        call    hex4
        ror     al, 4
        call    hex4
        pop     ax
        ret
hex16:  ror     ax, 8           ; Выдать 16 бит
        call    hex8
        ror     ax, 8
        call    hex8
        ret
; ----------------------------------------------------------------------
