; Как вывести число FPU

;       +3       +2       +1       +0
; sppppppp pmmmmmmm mmmmmmmm mmmmmmmm

; Сконвертировать в знаковое число int16
; ----------------------------------------------------------------------
fp_toint16:

        xor     ax, ax
        mov     cx, [si+2]      ; Получить порядок числа
        shl     cx, 1
        shr     cx, 8
        sub     cl, 0x7E
        jb      .next           ; Порядок меньше чем 0
        mov     bx, [si+1]      ; Максимальное доступное 16-битное число
        or      bh, $80         ; Установка скрытой единицы
@@:     shl     bx, 1           ; Сдвиг необходимое количество раз
        rcl     ax, 1
        loop    @b
.next:  test    [si+3], byte $80 ; Проверка знака
        jns     .end
        neg     ax
.end:   ret

; Печать дробной части float
; ----------------------------------------------------------------------
fp_print_fract:

        push    ax bx cx dx
        mov     al, '.'
        call    putch
        mov     cx, [si+2]
        shl     cx, 1
        shr     cx, 8           ; Порядок
        mov     bx, [si+1]
        mov     ah, [si]
        mov     al, 0
        or      bh, 0x80        ; bx:ax
        sub     cl, 0x7E
        jb      .less
        je      .show
.more:  shl     ax, 1           ; Коррекция влево
        rcl     bx, 1
        loop    .more
        jmp     .show
.less:  neg     cl
@@:     shr     bx, 1           ; Коррекция вправо
        rcr     ax, 1
        loop    @b
.show:  mov     cx, 6           ; 6 знаков
.rept:  mov     dx, 10
        mul     dx
        push    ax
        mov     ax, bx
        add     ax, dx          ; Перенос
        mov     dx, 10
        mul     dx
        xchg    ax, bx
        mov     al, dl
        add     al, '0'
        call    putch
        pop     ax
        loop   .rept
        pop     dx cx bx ax
        ret

; Печать приблизительного float-point числа
; ----------------------------------------------------------------------
fp_print:

        call    fp_toint16
        call    printi
        call    fp_print_fract
        ret

; Печать десятичного числа AX, DS:SI - где начало
; ----------------------------------------------------------------------
printi: push    si dx cx bx ax
        mov     [.sgn], byte 0      ; Определить положительное
        and     ax, ax
        jns     .plus
        mov     [.sgn], byte 1      ; Либо число отрицательное
        neg     ax
.plus:  mov     si, .buf + 6
        mov     [si], byte 0
        mov     bx, 10
.next:  xor     dx, dx
        div     bx
        add     dl, '0'
        dec     si
        mov     [si], dl
        and     ax, ax
        jne     .next
        cmp     [.sgn], byte 0
        je      .nosgn
        dec     si
        mov     [si], byte '-'      ; Вывести минус, если отрицательное
.nosgn: pop     ax bx cx dx
        call    print
        pop     si
        ret

.buf:   db      0,6,5,5,3,6,0
.sgn:   db      0
