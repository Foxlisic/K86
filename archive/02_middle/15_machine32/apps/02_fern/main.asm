
PRECISE     equ     11
; ----------------------------------------------------------------------

            org     0

            mov     ax, cs
            mov     ds, ax

            ; 320 x 200 x 256
            mov     dx, 3d8h
            mov     al, 3
            out     dx, al

            mov     ax, $A000
            mov     es, ax
            xor     di, di
            mov     cx, 64000

            ; Циклический расчет нового значения
rtlp:       call    lfsrfibo
            cmp     ax, 655     ; .01
            jbe     case0
            cmp     ax, 5242    ; .08
            jbe     case1
            cmp     ax, 9830    ; .15
            jbe     case2
            mov     si, matrix3
            jmp     caseout
case0:      mov     si, matrix0
            jmp     caseout
case1:      mov     si, matrix1
            jmp     caseout
case2:      mov     si, matrix2
caseout:    call    multmatxy

            ; x = nextx, y = nexty
            mov     ax, [nextx]
            mov     [x], ax
            sar     ax, (PRECISE-4)
            mov     si, ax
            add     si, 160

            mov     ax, [nexty]
            mov     [y], ax
            sar     ax, (PRECISE-4)

            ; Проверка попадания точки
            cmp     ax, 200
            jnb     rtlp
            cmp     si, 320
            jnb     rtlp

            ; Расчет положения точки
            mov     bx, 320
            imul    bx
            add     si, ax
            neg     si
            mov     bx, [rng+2]
            and     bl, 0x08
            or      bl, 0x02
            mov     [es:si + 320*180], bl

            jmp     rtlp

; Знаковое умножение AX*BX => AX
mult:       push    cx dx
            xor     dx, dx
            imul    bx      ; Получаем в DX:AX новое значение
            mov     cx, PRECISE
@@:         sar     dx, 1   ; Коррекция результата
            rcr     ax, 1
            loop    @b
            pop     dx cx
            ret

            ; Умножение A*x + B*y + C => AX
multmat:    mov     ax, [x]
            mov     bx, [si+0]
            call    mult
            mov     cx, ax
            mov     ax, [y]
            mov     bx, [si+2]
            call    mult
            add     ax, cx
            add     ax, [si+4]
            ret

            ; nextx, nexty
multmatxy:  call    multmat
            mov     [nextx], ax
            add     si, 6
            call    multmat
            mov     [nexty], ax
            ret

x:          dw      0
y:          dw      0
nextx:      dw      0
nexty:      dw      0

; ----------------------------------------------------------------------
; Линейный генератор
; ----------------------------------------------------------------------

linear:     push    bx dx
            mov     ax, [rng+0]
            mov     bx, 106
            mul     bx
            add     ax, 1283
            mov     bx, 6075
            div     bx
            xchg    ax, dx
            mov     [rng+0], ax
            pop     dx bx
            ret

; ----------------------------------------------------------------------
; Регистр сдвига с линейной обратной связью (BX:AX следующее значение)
; ----------------------------------------------------------------------

lfsrfibo:   push    cx dx
            mov     ax, [rng+0]
            mov     bx, [rng+2]
            push    ax bx
            mov     cl, 9
            shr     bx, cl
            xor     ax, bx      ; 9
            mov     cl, 2
            shr     bx, cl
            xor     ax, bx      ; 11
            shr     bx, cl
            xor     ax, bx      ; 13
            dec     cx
            shr     bx, cl
            xor     ax, bx      ; 14
            shr     bx, cl
            xor     ax, bx      ; 15
            ror     al, 1       ; Бит окажется в старшем разряде
            and     al, 0x80
            xchg    ax, dx
            pop     bx ax
            shr     bx, 1
            rcr     ax, 1
            or      bh, dl
            mov     [rng+0], ax
            mov     [rng+2], bx
            pop     dx cx
            ret

rng:        dw      0x0000, 0x8000

; ----------------------------------------------------------------------
include     "params.asm"
