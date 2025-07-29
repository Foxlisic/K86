;
; СВЕРХ МИНИ БИОС
; INT 10h AH=00 SET VIDEO MODE 03h или 13h
;
        org     0

        dw      intstb, 0                   ; INT 0
        dw      intstb, 0                   ; INT 1
        dw      intstb, 0                   ; INT 2
        dw      intstb, 0                   ; INT 3
        dw      intstb, 0                   ; INT 4
        dw      intstb, 0                   ; INT 5
        dw      intstb, 0                   ; INT 6
        dw      intstb, 0                   ; INT 7
        dw      intstb, 0                   ; INT 8 :: IRQ0 Timer
        dw      intstb, 0                   ; INT 9 :: IRQ1 Keyboard
        dw      intstb, 0                   ; INT A :: IRQ2 VRetrace
        dw      intstb, 0                   ; INT B
        dw      intstb, 0                   ; INT C
        dw      intstb, 0                   ; INT D
        dw      intstb, 0                   ; INT E
        dw      intstb, 0                   ; INT F
        dw      int10h_address, 0           ; INT 10h

; ----------------------------------------------------------------------
; https://stanislavs.org/helppc/6845.html
; |7|6|5|4|3|2|1|0|  3D8 Mode Select Register
;  | | | | | | | `---- 1 = 80x25 text, 0 = 40x25 text
;  | | | | | | `----- 1 = 320x200 graphics, 0 = text
;  | | | | | `------ 1 = B/W, 0 = color
;  | | | | `------- 1 = enable video signal
;  | | | `-------- 1 = 640x200 B/W graphics
;  | | `--------- 1 = blink, 0 = no blink
;  `------------ unused

int10h_address:

        and     ah, ah
        jne     .end
        mov     ah, 1
        cmp     al, 03h
        je      .mode
        mov     ah, 2
        cmp     al, 13h
        je      .mode
.end:   iret
.mode:  mov     dx, 3D8h
        mov     al, ah
        out     dx, al
        iret

; Выход из обработанного прерывания: запись в $20 любого значения
intstb: out     ($20), al
        iret
