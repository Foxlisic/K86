; Установка сегментов и запуск видеорежима 320x200
macro screen13 {

        cli
        xor     ax, ax
        mov     ss, ax
        mov     ds, ax              ; SS=DS=0000h
        mov     ax, $A000
        mov     es, ax              ; ES = A000h
        mov     sp, $3800           ; Для Марсохода2 это высота памяти
        mov     ax, 13h
        int     10h
}
