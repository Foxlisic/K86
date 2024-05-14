
        org     0
START:  xor     ax, ax              ; Активация
        mov     es, ax
        mov     ds, ax
        mov     ss, ax
        mov     sp, $0800           ; 2K стековая высота
        mov     ah, $07
        call    CLS

        ; Прием данных от клавы
@@:     in      al, $64
        and     al, 1
        je      @b
        in      al, $60
        call    PRN
        jmp     @b

        hlt


; Очистка экрана; AH-параметры цвета
; ------------------------------------------------------------------------------
CLS:    push    es
        mov     es, [cs:B800]
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
        mov     al, $0E
        mov     dx, $3D4        ; Старший байт курсора
        out     dx, ax
        mov     al, $0F
        mov     ah, bl
        out     dx, ax          ; Младший байт курсора
        ret

; Печать символа AL
; ------------------------------------------------------------------------------
PRN:    push    ax bx cx dx di es
        mov     bx, [cs:CONF.locxy]
        cmp     al, 10
        je      short .rtn
        mov     cl, al
        mov     al, bh
        mov     ah, 80
        mul     ah
        add     al, bl
        adc     ah, 0
        xchg    ax, di
        add     di, di
        mov     es, [cs:B800]
        mov     al, cl
        mov     ah, [cs:CONF.clr]
        stosw
        inc     bl
        cmp     bl, 80
        jne     @f
.rtn:   mov     bl, 0
        inc     bh
        cmp     bh, 25
        jne     @f
        mov     bh, 24
        ; S:KROLL
@@:     xchg    ax, bx
        call    LOC
        pop     es di dx cx bx ax
        ret

; Параметры и конфигурации
; ------------------------------------------------------------------------------
B800:   dw      $B800
CONF:
.clr:   db      0                   ; Текущий цвет символов
.locxy: dw      0

; ------------------------------------------------------------------------------
        times   (4096-16-$) db 0
        jmp     $FF00 : $0000
        times   11      db 0
