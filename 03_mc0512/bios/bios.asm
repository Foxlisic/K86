
        org     0

        xor     ax, ax              ; Активация
        mov     es, ax
        mov     ds, ax
        mov     ss, ax
        mov     sp, $0800           ; 2K стековая высота
        mov     ah, $07
        call    CLS

        mov     ax, $014F
        call    LOC

        hlt

; Очистка экрана; AH-параметры цвета
; ------------------------------------------------------------------------------
CLS:    push    es
        push    $B800
        pop     es
        mov     [cs:CONF.clr], ah
        mov     al, 0
        xor     di, di
        mov     cx, 2000
        rep     stosw
        xor     ax, ax
        call    LOC
        pop     es
        ret

; Поставить курсор в (AH=Y,AL=X)
; ------------------------------------------------------------------------------
LOC:    mov     [cs:CONF.locxy], ax
        mov     bh, 0
        mov     bl, al          ; BX=x
        mov     al, 80
        mul     ah              ; AX=80*y
        add     bx, ax          ; BX=80*y + x
        mov     ah, bh
        mov     al, 0x0E
        mov     dx, 0x3D4       ; Старший байт курсора
        out     dx, ax
        mov     al, 0x0F
        mov     ah, bl
        out     dx, ax          ; Младший байт курсора
        ret

; Печать символа
; ------------------------------------------------------------------------------
PRN:    ret

; Параметры и конфигурации
; ------------------------------------------------------------------------------
CONF:
.clr:   db      0                   ; Текущий цвет символов
.locxy: dw      0

; ------------------------------------------------------------------------------
times   (4096-16-$) db 0
        jmp     $FF00 : $0000
times   11      db 0
