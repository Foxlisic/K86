
; По заданному SI проверить паттерн
; ----------------------------------------------------------------------

check_data:

@@:         mov     al, [si]
            mov     ah, [cs:di]
            cmp     al, ah
            jne     error
            inc     si
            inc     di
            loop    @b
            ret

; Проверить стек (убрать DIT из запроса)
; ----------------------------------------------------------------------

check_stack:

@@:         mov     ax, [si]        ; Исходный
            mov     bx, [cs:di]     ; Таргет
            and     ax, 0x8ff       ; DIT убрать
            and     bx, 0x8ff
            cmp     ax, bx
            jne     error
            add     si, 2
            add     di, 2
            loop    @b
            ret

; Error / Success
; ----------------------------------------------------------------------
error:      push    word [si]
            push    si
            mov     si, _strerr
            call    PRINT
            pop     ax
            call    PRINTHEX
            add     [cs:cursor], word 2
            pop     ax
            call    PRINTHEX
            jmp     $

; ===
print_ok:   mov     si, _strok
            call    PRINT
            jmp     $

; Печать CS:SI
; ----------------------------------------------------------------------

PRINT:      push    ds es
            mov     ax, cs
            mov     ds, ax
            mov     ax, 0xb800
            mov     es, ax
            mov     di, [cursor]
@@:         lodsb
            and     al, al
            je      @f
            mov     ah, 0x07
            stosw
            jmp     @b
@@:         mov     [cursor], di
            pop     es ds
            ret

; ----------------------------------------------------------------------
PRINTHEX:   mov     cx, 4
            mov     di, [cs:cursor]
            push    es
            mov     bx, 0xb800
            mov     es, bx
.LP:        rol     ax, 4
            mov     bl, al
            and     bl, 15
            cmp     bl, 10
            jb      @f
            add     bl, 7
@@:         add     bl, '0'
            mov     bh, 0x07
            mov     [es:di], bx
            inc     di
            inc     di
            loop    .LP
            mov     [cs:cursor], di
            pop     es
            ret

cursor:     dw      0
