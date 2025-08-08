        org     100h
        include "../macro.asm"
start:  screen  13
        mov     cx, 64000       ; Сгенерировать случайный шум
        xor     di, di
@@:     add     al, ah
        imul    ax, 3235
        inc     ax
        stosb
        loop    @b
        mov     si, 0           ; Начать сортировку
        mov     di, 64000
        call    qsort
        hlt
qsort:  push    si di           ; L-si, R-di
        mov     ax, si
        mov     bx, di
        shr     ax, 1
        shr     bx, 1
        add     bx, ax          ; BX=середина
        mov     cl, [es:bx]     ; CL=PIVOT
.w1:    cmp     [es:si], cl     ; WHILE (Arr[si] < pivot): si = si + 1
        jnb     .w2
        inc     si
        jmp     .w1
.w2:    cmp     [es:di], cl     ; WHILE (Arr[di] > pivot): di = di - 1
        jbe     .w3
        dec     di
        jmp     .w2
.w3:    cmp     si, di          ; IF a% <= b% THEN
        ja      .w4
        mov     al, [es:si]     ; SWAP Arr(a%), Arr(b%)
        xchg    al, [es:di]
        xchg    al, [es:si]
        inc     si
        dec     di
        cmp     si, di          ; LOOP WHILE a% <= b%
        jbe     .w1
.w4:    pop     bx ax           ; AX-было ранее L, BX-R
        cmp     ax, di          ; IF l% < b% THEN QSort l%, b%
        jnb     .s1
        push    ax bx si di
        mov     si, ax          ; ax=l%, di=b%
        call    qsort
        pop     di si bx ax
.s1:    cmp     si, bx          ; IF a% < r% THEN QSort a%, r%
        jnb     .s2
        push    ax bx si di
        mov     di, bx
        call    qsort
        pop     di si bx ax
.s2:    ret

