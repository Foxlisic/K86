        org     100h
; ------------------------------------------------------------------------------
start:  cli
        xor     ax, ax
        mov     ss, ax
        xor     sp, sp
        mov     ax, $B800
        mov     es, ax
        mov     ax, cs
        mov     ds, ax

        ; Забор
        xor     di, di
        mov     ah, $07
        mov     cx, 1000
@@:     mov     al, '/'
        stosw
        mov     al, '\'
        stosw
        loop    @b

        ; Надпись
        mov     ah, $17
        mov     si, s1
        mov     di, (11*80 + 32)*2

@@:     lodsb
        and     al, al
        je      $
        stosw
        jmp     @b

s1:     db      " PRIVET DRIVE! ",0
