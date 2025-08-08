; ----------------------------------------------------------------------
; ФУНКЦИИ ЭКРАНА
; ----------------------------------------------------------------------

; Видеорежим 80 x 25
; ----------------------------------------------------------------------
screen3:

        mov     ax, $B800
        mov     es, ax
        jmp     screen13.set

; Видеорежим 320 x 200 x 256
; ----------------------------------------------------------------------
screen13:

        mov     ax, $A000
        mov     es, ax
        mov     al, 3

        ; Видеорежим
.set:   mov     dx, 3d8h
        out     dx, al
        mov     ax, cs          ; Установка текущих сегментов
        mov     ds, ax
        ret

; Очистка экрана в цвет AL
; ----------------------------------------------------------------------
cls:    push    ax
        xor     di, di
        mov     dx, 0x3d8
        in      al, dx
        mov     bl, al
        pop     ax
        cmp     bl, 0
        jle     .v3

        ; 320x200
        mov     cx, 64000
        rep     stosb
        ret

        ; 80x25
.v3:    mov     cx, 2000
        mov     ah, al
        mov     al, 0
        rep     stosw
        xor     bx, bx
        call    set_cursor_bx
        ret

; Загрузка положения курсора
; ----------------------------------------------------------------------
load_cursor_bx:

        push    dx ax
        mov     dx, 0x3d4
        mov     al, 0x0e
        out     dx, al              ; Запрос старшего байта
        inc     dx
        in      al, dx              ; Получение старшего байта
        mov     bh, al
        dec     dx
        mov     al, 0x0f
        out     dx, al
        inc     dx
        in      al, dx              ; Получение младшего байта
        mov     bl, al
        add     bx, bx
        pop     ax dx
        ret

; Сохранение нового положения курсора BX
; ----------------------------------------------------------------------
set_cursor_bx:

        push    dx ax
        shr     bx, 1
        mov     dx, 0x3d4
        mov     al, 0x0e
        mov     ah, bh
        out     dx, ax              ; Запись старшего байта
        mov     al, 0x0f
        mov     ah, bl
        out     dx, ax              ; Запись младшего байта
        pop     ax dx
        ret

; Пропечатка строки ds:si
; ----------------------------------------------------------------------
print:  push    si bx ax
        call    load_cursor_bx
.char:  lodsb
        and     al, al
        je      .stop
        mov     [es: bx], al
        add     bx, 2
        jmp     .char
.stop:  call    set_cursor_bx
        pop     ax bx si
        ret

; Печать символа AL
; ----------------------------------------------------------------------
putch:  push    ax bx
        call    load_cursor_bx
        mov     [es: bx], al
        add     bx, 2
        call    set_cursor_bx
        pop     bx ax
        ret

; Печатать 16 битный
print_hex16:

        push    ax
        mov     cx, 4
@@:     rol     ax, 4
        push    ax
        and     al, 0x0F
        daa
        add     al, 0xF0
        adc     al, 0x40
        call    putch
        pop     ax
        loop    @b
        pop     ax
        ret
