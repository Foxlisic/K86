
; Unit: Rotation

            org     100h

include     "intro.asm"

; Вычисления
; ----------------------------------------------------------------------

            ; add word tests
            mov     ax, 0xffff
            mov     bx, 0x0001
            add     bx, ax                  ; [1] add word reg16, reg16
            mov     word [0], ax
            mov     word [2], bx
            pushf

            mov     dx, 0xffff
            mov     word [4], 0xffff
            add     word [4], dx            ; [2] add word reg16, mem16
            mov     word [6], dx
            pushf

            mov     cx, 0x0001
            mov     word [8], 0x0002
            add     cx, word [8]            ; [3] add word mem16, reg16
            mov     word [10], cx
            pushf

            mov     ax, 0x0001
            add     ax, 0x7fff              ; [4] add word imm16, ac16
            mov     word [12], ax
            pushf

            mov     bp, 0x8000
            db      0x83,0xc5,0xff          ; [5] add word imm8, reg16
            mov     word [14], bp
            pushf

            mov     bp, 0xc783
            add     si, 0xeb2a              ; [6] add word imm16, reg16
            mov     word [16], si
            pushf

            mov     word [18], 0x8960
            add     word [18], 0x0a95       ; [7] add word imm16, mem16
            pushf

            mov     word [20], 0xf1e1
            dw 0x0683, 0x0014               ; [8] add word imm8, mem16
            db 0x64
            pushf

            ; add byte tests
            mov     byte [22], 0x01
            add     byte [22], 0xff         ; [9] add byte imm8, mem8
            pushf

            mov     dh, 0xff
            add     dh, 0xff                ; [10] add byte imm8, reg8
            mov     word [23], dx
            pushf

            mov     al, 0x01
            add     al, 0x02                ; [11] add byte imm8, acum8
            mov     word [25], ax
            pushf

            mov     byte [27], 0x7f
            mov     ch, 0x01
            add     ch, byte [27]            ; [12] add byte mem8, reg8
            mov     word [28], cx
            pushf

            mov     bl, 0x80
            mov     byte [30], 0xff
            add     byte [30], bl           ; [13] add byte reg8, mem8
            mov     word [31], bx
            pushf

            mov     al, 0xa6
            mov     ah, 0x86
            add     ah, al                  ; [14] add byte reg8, reg8
            mov     word [33], ax
            pushf

            ; adc word tests
            mov     ax, 0xffff
            mov     bx, 0x0001
            adc     bx, ax                  ; [15] adc word reg16, reg16
            mov     word [35], ax
            mov     word [37], bx
            pushf

            mov     dx, 0xffff
            mov     word [39], 0xffff
            adc     word [39], dx           ; [16] adc word reg16, mem16
            mov     word [41], dx
            pushf

            mov     cx, 0x0001
            mov     word [43], 0x0002
            adc     cx, word [43]           ; [17] adc word mem16, reg16
            mov     word [45], cx
            pushf
; ---
            mov     ax, 0x0001
            adc     ax, 0x7fff              ; [18] adc word imm16, ac16
            mov     word [47], ax
            pushf

            mov     bp, 0x8000
            db      0x83,0xd5,0xff          ; [19] adc word imm8, reg16
            mov     word [49], bp
            pushf

            mov     si, 0x77d3
            adc     si, 0x8425              ; [20] adc word imm16, reg16
            mov     word  [51], si
            pushf

            mov     word [53], 0xeba0
            adc     word [53], 0xd3c1       ; [21] adc word imm16, mem16
            pushf

            mov     word [55], 0x7f50
            dw      0x1683, 0x0037
            db      0xf5
            pushf

            ; adc byte tests
            mov     byte [57], 0x01
            adc     byte [57], 0xff
            pushf

            mov     dh, 0xff
            adc     dh, 0xff
            mov     word [58], dx
            pushf

            mov     al, 0x01
            adc     al, 0x02
            mov     word [60], ax
            pushf

            mov     byte [62], 0x7f
            mov     ch, 0x01
            adc     ch, byte [62]
            mov     word [63], cx
            pushf

            mov     byte bl, 0x80
            mov     byte [65], 0xff
            adc     byte [65], bl
            mov     word [66], bx
            pushf

            mov     al, 0xb9
            mov     ah, 0xd3
            adc     ah, al
            mov     word [68], ax
            pushf

            ; inc word tests
            mov     di, 0xffff
            inc     di
            mov     word [70], di
            pushf

            mov     bp, 0x7fff
            db      0xff, 0xc5
            mov     word [72], bp
            pushf

            mov     word [74], 0x7412
            inc     word [74]
            pushf

            ; inc byte tests
            mov     dl, 0x7f
            inc     dl
            mov     word [76], dx
            pushf

            mov     byte [77], 0xff
            inc     byte [77]
            pushf

            mov     byte [78], 0xb5
            inc     byte [78]
            pushf
; ----------------------------------------------------------------------

            ; Проверка
            mov     si, 0
            mov     di, _data
            mov     cx, 40
            call    check_data

            ; Сравнить флаги
            mov     si, 0xb0 + 0x0c
            mov     di, _stack + 0x0c
            mov     cx, 34
            call    check_stack

            jmp     print_ok

_strok:     db      "ADD tests [data & stack] completed!",0
_strerr:    db      "ADD tests ERROR at: ",0

; Паттерн, который должен получиться в итоге
; ----------------------------------------------------------------------
_data:      db      0xFF, 0xFF, 0x00, 0x00, 0xFE, 0xFF, 0xFF, 0xFF ; 00
            db      0x02, 0x00, 0x03, 0x00, 0x00, 0x80, 0xFF, 0x7F ; 08
            db      0x2A, 0xEB, 0xF5, 0x93, 0x45, 0xF2, 0x00, 0xFF ; 10
            db      0xFE, 0x03, 0x80, 0x7F, 0x03, 0x80, 0x7F, 0x80 ; 18
            db      0x00, 0xA6, 0x2C, 0xFF, 0xFF, 0x01, 0x00, 0xFF ; 20
            db      0xFF, 0xFF, 0xFF, 0x02, 0x00, 0x04, 0x00, 0x00 ; 28
            db      0x80, 0xFF, 0x7F, 0xF9, 0xFB, 0x61, 0xBF, 0x46 ; 30
            db      0x7F, 0x01, 0xFF, 0xFF, 0x04, 0x80, 0x7F, 0x04 ; 38
            db      0x80, 0x7F, 0x80, 0x00, 0xB9, 0x8D, 0x00, 0x00 ; 40
            db      0x00, 0x80, 0x13, 0x74, 0x80, 0x00, 0xB6, 0x00 ; 48

_stack:     db      0xDF, 0x01, 0xB2, 0x18, 0xB9, 0x8D, 0xC5, 0x02 ; b0
            db      0x8F, 0x4B, 0x83, 0x30, 0x83, 0x30, 0x57, 0x30 ; b8
            db      0x93, 0x38, 0x03, 0x30, 0x97, 0x38, 0x57, 0x30 ; c0
            db      0x87, 0x30, 0x03, 0x38, 0x92, 0x38, 0x02, 0x30 ; c8
            db      0x97, 0x30, 0x13, 0x30, 0x03, 0x30, 0x83, 0x30 ; d0
            db      0x86, 0x30, 0x07, 0x38, 0x96, 0x38, 0x02, 0x30 ; d8
            db      0x97, 0x30, 0x13, 0x30, 0x03, 0x38, 0x03, 0x38 ; e0
            db      0x92, 0x38, 0x06, 0x30, 0x93, 0x30, 0x57, 0x30 ; e8
            db      0x82, 0x30, 0x86, 0x30, 0x82, 0x30, 0x07, 0x38 ; f0
            db      0x96, 0x38, 0x06, 0x30, 0x93, 0x30, 0x57, 0x30 ; f8
; ----------------------------------------------------------------------

include     "func.asm"
