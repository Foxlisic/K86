
; Unit: Rotation

            org     100h

include     "intro.asm"

; Вычисления
; ----------------------------------------------------------------------

            mov     ax, 0x3b5e
            mov     bx, 0xc8a7
            mov     word [0], 0x2072
            mov     word [2], 0x3e79

            rcl     ax, 1
            pushf
            mov     [32], ax

            rcl     word [0], 1
            pushf

            mov     cx, 0x100
            rcl     bx, cl
            pushf
            mov     [34], bx

            mov     cx, 0xffff
            mov     dx, bx
            rcl     dx, cl
            pushf
            mov     [36], dx

            mov     cl, 0x8
            rcl     cx, cl
            pushf
            mov     [38], bx

            mov     cl, 0x4
            rcl     word [2], cl
            pushf

            ; rcl byte operations
            mov     dx, 0x5904
            mov     ax, 0xbe7c
            mov     word [4], 0xd62f
            mov     word [6], 0x6fd8
            rcl     ah, 1
            pushf

            mov     [40], ax
            rcl     byte [5], 1
            pushf

            mov     cl, 0x7
            rcl     dl, cl
            pushf

            mov     [42], dx
            rcl     byte [6], cl
            pushf

            ; rcr word operations
            mov     ax, 0x15d6
            mov     bx, 0x8307
            mov     word [8], 0x9ab7
            mov     word [10], 0x28b6

            rcr     ax, 1
            pushf
            mov     [44], ax

            rcr    word [8], 1
            pushf

            mov     cx, 0x100
            rcr     bx, cl
            pushf
            mov     [46], bx

            mov     cx, 0xffff
            mov     dx, bx
            rcr     dx, cl
            pushf
            mov     [48], dx

            mov     cl, 0x5
            rcr     bx, cl
            pushf
            mov     [50], bx

            mov     cl, 0x4
            rcr     word [10], cl
            pushf

            ; rcr byte operations
            mov     dx, 0x7eaa
            mov     ax, 0x3a8d
            mov     word [12], 0xa414
            mov     word [14], 0x2838

            rcr     ah, 1
            pushf
            mov     [52], ax

            rcr     byte [13], 1
            pushf

            mov     cl, 0x7
            rcr     dl, cl
            pushf
            mov     [54], dx

            rcr     byte [14], cl
            pushf

            ; rol word operations
            mov     ax, 0x020d
            mov     bx, 0x8d5a
            mov     word [16], 0x28dd
            mov     word [18], 0xd74a

            rol     ax, 1
            pushf
            mov     [56], ax
            rol     word [16], 1
            pushf

            mov     cx, 0x100
            rol     bx, cl
            pushf
            mov     [58], bx

            mov     cx, 0xffff
            mov     dx, bx
            rol     dx, cl
            pushf
            mov     [60], dx

            mov     cl, 0x4
            rol     bx, cl
            pushf
            mov     [62], bx

            mov     cl, 0x4
            rol     word [18], cl
            pushf

            ; rol byte operations
            mov     dx, 0x9d09
            mov     ax, 0xc948
            mov     word [20], 0x0b80
            mov     word [22], 0x48e8

            rol     ah, 1
            pushf
            mov     [64], ax

            rol     byte [21], 1
            pushf

            mov     cl, 0x7
            rol     dl, cl
            pushf
            mov     [66], dx

            rol     byte [22], cl
            pushf

            ; ror word operations
            mov     ax, 0xf25e
            mov     bx, 0x2eb5
            mov     word [24], 0x0151
            mov     word [26], 0x7237

            ror     ax, 1
            pushf
            mov     [68], ax

            ror     word [24], 1
            pushf

            mov     cx, 0x100
            ror     bx, cl
            pushf                       ; BEh
            mov     [70], bx

            mov     cx, 0xffff
            mov     dx, bx
            ror     dx, cl
            pushf
            mov     [72], dx

            mov     cl, 0x04
            ror     bx, cl
            pushf
            mov     [74], bx

            mov     cl, 0x4
            ror     word [26], cl
            pushf

            ; ror byte operations
            mov     dx, 0x4288
            mov     ax, 0x8bab
            mov     word [28], 0x5dd9
            mov     word [30], 0xc7f7

            ror     ah, 1
            pushf
            mov     [76], ax

            ror     byte [29], 1
            pushf

            mov     cl, 0x7
            ror     dl, cl
            pushf
            mov     [78], dx
            ror     byte [30], cl
            pushf

; ----------------------------------------------------------------------

            ; Проверка
            mov     si, 0
            mov     di, _data
            mov     cx, 40
            call    check_data

            ; Сравнить флаги
            mov     si, 0xb0
            mov     di, _stack
            mov     cx, 40
            call    check_stack

            jmp     print_ok

_strok:     db      "Rotate tests (data & stack) completed!",0
_strerr:    db      "Rotate tests ERROR at: ",0

; Паттерн, который должен получиться в итоге
; ----------------------------------------------------------------------
_data:      db      0xE4, 0x40, 0x99, 0xE7, 0x2F, 0xAD, 0x36, 0x6F ; 00
            db      0x5B, 0x4D, 0x8B, 0xC2, 0x14, 0x52, 0xE0, 0x28 ; 08
            db      0xBA, 0x51, 0xAD, 0x74, 0x80, 0x16, 0x74, 0x48 ; 10
            db      0xA8, 0x80, 0x23, 0x77, 0xD9, 0xAE, 0xEF, 0xC7 ; 18
            db      0xBC, 0x76, 0xA7, 0xC8, 0x14, 0xD9, 0xA7, 0xC8 ; 20
            db      0x7C, 0x7D, 0x41, 0x59, 0xEB, 0x0A, 0x07, 0x83 ; 28
            db      0x3E, 0x18, 0x18, 0x74, 0x8D, 0x1D, 0xA9, 0x7E ; 30
            db      0x1A, 0x04, 0x5A, 0x8D, 0xAD, 0x46, 0xA8, 0xD5 ; 38
            db      0x48, 0x93, 0x84, 0x9D, 0x2F, 0x79, 0xB5, 0x2E ; 40
            db      0x6A, 0x5D, 0xEB, 0x52, 0xAB, 0xC5, 0x11, 0x42 ; 48

_stack:     db      0x47, 0x32, 0x46, 0x32, 0x47, 0x3a, 0x47, 0x32 ; b0
            db      0x46, 0x3a, 0x46, 0x3a, 0x46, 0x3a, 0x47, 0x3a ; b8
            db      0x47, 0x3a, 0x46, 0x3a, 0x46, 0x32, 0x46, 0x3a ; c0
            db      0x46, 0x32, 0x47, 0x32, 0x47, 0x3a, 0x46, 0x3a ; c8
            db      0x47, 0x3a, 0x46, 0x32, 0x46, 0x32, 0x46, 0x32 ; d0
            db      0x46, 0x32, 0x46, 0x3a, 0x46, 0x3a, 0x46, 0x32 ; d8
            db      0x46, 0x32, 0x46, 0x3a, 0x46, 0x32, 0x47, 0x3a ; e0
            db      0x47, 0x3a, 0x46, 0x32, 0x46, 0x32, 0x46, 0x32 ; e8
            db      0x47, 0x32, 0x47, 0x3a, 0x47, 0x32, 0x47, 0x3a ; f0
            db      0x47, 0x32, 0x46, 0x32, 0x46, 0x32, 0x46, 0x32 ; f8
; ----------------------------------------------------------------------

include     "func.asm"
