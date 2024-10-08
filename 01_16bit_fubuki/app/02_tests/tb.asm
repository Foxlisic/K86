        org     100h
; ------------------------------------------------------------------------------
start:  cli
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        xor     sp, sp

        mov     ax, $B800
        mov     es, ax
        mov     [es:0], word $0235
        jmp     $
