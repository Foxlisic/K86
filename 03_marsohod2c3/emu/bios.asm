include "../app/macro.asm"
boot    512

        mov     si, s
        mov     di, 0
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

final
