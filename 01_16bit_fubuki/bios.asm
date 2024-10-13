;
; СВЕРХ МИНИ БИОС
; INT 10h AH=00 SET VIDEO MODE 03h или 13h
;
        org     0
        times   16  dd 0
        dw      int10h_address, 0           ; INT 10h

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
