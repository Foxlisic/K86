; ------------------------------------------------------------------------------
;       ПОЛУБИОС: ПОЛУПОКЕР ОНЛИНЭ
; ------------------------------------------------------------------------------

maxsize equ     1024

        org     0
begin:  xor     ax, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, $1000
        mov     ax, cs
        mov     ds, ax

        mov     si, s
        mov     di, $B800
        mov     ah, $17
@@:     lodsb
        and     al, al
        je      stop
        stosw
        jmp     @b

        ; Тестовый прием клавиш
stop:   in      al, $64
        test    al, 1
        je      stop
        in      al, $60
        stosw
        jmp     stop

        hlt


s       db      "Hello world!",0

; ------------------------------------------------------------------------------
;       ТУПЕЙШАЯ РЕАЛИЗАЦИЯ НЕИЗВЕСТНО ЧЕГО ВООБЩЕ
; ------------------------------------------------------------------------------

        times   ((maxsize - 16) - $) db 0
        jmp     (0x10000 - maxsize/16) : begin
        times   (maxsize-$) db 0xFF
