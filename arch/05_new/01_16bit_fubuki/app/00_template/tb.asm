include "../macro.asm"
; ------------------------------------------------------------------------------
        org     100h
; ------------------------------------------------------------------------------
start:
        screen  3
        vector  9, kbd
        vector  10, vsync
        palette 0, 0, 8, 16

        ; Проверка вывода на экран
        xor     di, di
        mov     ah, $07
        mov     cx, 1000
@@:     mov     al, 0x2F ; '/'
        stosw
        mov     al, 0x5C ; '\'
        stosw
        loop    @b

        ; Надпись
        mov     ah, $17
        mov     si, s1
        mov     di, (11*80 + 32)*2

@@:     lodsb
        and     al, al
        je      stop
        stosw
        jmp     @b

; Проверка клавиатуры
stop:   xor     di, di
        sti
        hlt
; ----------------------------------------------------------------------
s1:     db      " PRIVET DRIVE! ",0
; ----------------------------------------------------------------------

; Проверка клавиатуры
kbd:    mov     ah, 17h
        in      al, $60
        stosw
        out     ($20), al
        iret

; Проверка VSync
vsync:  push    di
        mov     di, 160*12
        inc     word [es:di]
        pop     di
        out     ($20), al
        iret
