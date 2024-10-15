include "../macro.asm"
; ------------------------------------------------------------------------------
        org     100h
; ------------------------------------------------------------------------------
start:
        screen  13

        ; Сгенерировать случайный шум
        mov     cx, 64000
        xor     di, di
@@:     add     al, ah
        imul    ax, 3235
        inc     ax
        stosb
        loop    @b

        ; Начать сортировку
        mov     si, 0
        mov     di, 64000
        call    qsort

        ;xor ax, ax
        ;int 16h
        ;int3

        hlt

        ; L-si, R-di
qsort:  push    si di

        mov     ax, si
        mov     bx, di
        shr     ax, 1
        shr     bx, 1
        add     bx, ax              ; BX=середина
        mov     cl, [es:bx]         ; CL=PIVOT

        ; WHILE (Arr[si] < pivot): si = si + 1
.w1:    cmp     [es:si], cl
        jnb     .w2
        inc     si
        jmp     .w1

        ; WHILE (Arr[di] > pivot): di = di - 1
.w2:    cmp     [es:di], cl
        jbe     .w3
        dec     di
        jmp     .w2

        ; IF a% <= b% THEN
.w3:    cmp     si, di
        ja      .w4

        ; SWAP Arr(a%), Arr(b%)
        mov     al, [es:si]
        xchg    al, [es:di]
        xchg    al, [es:si]
        inc     si
        dec     di

        ; LOOP WHILE a% <= b%
.w4:    cmp     si, di
        jbe     .w1

        ; AX-было ранее L, BX-R
        pop     bx ax

        ; IF l% < b% THEN QSort l%, b%
        cmp     ax, di          ; ax=l%, di=b%
        jnb     .s1
        push    ax bx si di
        mov     si, ax          ; L..B
        call    qsort
        pop     di si bx ax

        ; IF a% < r% THEN QSort a%, r%
.s1:    cmp     si, bx          ; si=r%, bx=r%
        jnb     .s2
        push    ax bx si di
        mov     di, bx          ; A..R
        call    qsort
        pop     di si bx ax

        ; END SUB
.s2:    ret

