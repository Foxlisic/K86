
        org     0
        
        mov     cx, 3
@@:     call    far 0xf000 : t2
        mov     dx, 4
        hlt        

t1:     dd      0x1F2353AA
t2:     retf
        hlt

; ----------------------------------------------------------------------
; Окончание ROM всегда одинаковое
; ----------------------------------------------------------------------

        times   ($fff0-$) db 0xFF
        jmp     far 0xF000:0x0000            ; 5 Байт
        db      '12/01/22', 0x00, 0xFE, 0x00 ; 11 байт Я дунно что делает эта строка

