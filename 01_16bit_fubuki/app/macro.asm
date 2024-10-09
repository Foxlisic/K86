; Установка сегментов и запуск видеорежима 320x200
macro screen13 {

        mov     ax, 13h
        int     10h
        xor     ax, ax
        mov     ss, ax
        mov     ds, ax
        mov     ax, $A000
        mov     es, ax
}
