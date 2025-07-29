
        include "../macro.asm"
        org     100h

        screen  13

        mov     ax, $C000
        mov     es, ax
        mov     si, draw
        xor     di, di
        mov     cx, size
        rep     movsb

        mov     dx, $3C0        ; Выбрать страницу
        mov     al, 0
        out     dx, al

        mov     al, 0           ; Рендеринг
        mov     dx, $300
        out     dx, al

        hlt

draw:
        vidaccill   160,100,40,6
        vidaccirc   160,100,40,15
        vidacline   160,10,240,150,2
        vidacpoly   80,150,3
        vidacpoly   160,10,4
        vidacrect   20,20,30,25,5
        vidacfill   40,40,70,50,6

        db 0
size    = $ - draw
