; Установка сегментов и запуск видеорежима
; ----------------------------------------------------------------------

macro screen mode
{
        cli
        xor     ax, ax
        mov     sp, ax
        mov     ss, ax
        mov     ds, ax
if mode = 13
        mov     ax, $A000
        mov     es, ax
        mov     ax, 13h
end if
if mode = 3
        mov     ax, $B800
        mov     es, ax
        mov     ax, 03h
end if
        int     10h
}

; Установка вектора прерываний
; ----------------------------------------------------------------------
macro vector n, addr
{
        mov     [4*n], word addr
        mov     [4*n+2], cs
}

; Палитра
; ----------------------------------------------------------------------
macro palette i, r, g, b
{
        mov     al, i
        mov     dx, 968
        out     dx, al
        inc     dx
        mov     al, r
        out     dx, al
        mov     al, g
        out     dx, al
        mov     al, b
        out     dx, al
}
