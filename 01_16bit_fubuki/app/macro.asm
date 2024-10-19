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

; Объявления для VIDAC
; ----------------------------------------------------------------------

; Линия
macro vidacline x1, y1, x2, y2, c
{
        db      1
        dw      x1, y1, x2, y2
        db      c
}

; Пустой прямоугольник
macro vidacrect x1, y1, x2, y2, c
{
        db      2
        dw      x1, y1, x2, y2
        db      c
}

; Закрашенный прямоугольник
macro vidacfill x1, y1, x2, y2, c
{
        db      3
        dw      x1, y1, x2, y2
        db      c
}

; Полигональная линия
macro vidacpoly x2, y2, c
{
        db      4
        dw      x2, y2
        db      c
}

macro vidaccirc x, y, r, c
{
        db      5
        dw      x, y, r
        db      c
}

macro vidaccill x, y, r, c
{
        db      6
        dw      x, y, r
        db      c
}
