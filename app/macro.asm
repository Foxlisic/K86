; Задать стартовые параметры
macro boot S {

maxsize equ S
        org     0
begin:  mov     ax, $B800
        mov     es, ax
        xor     ax, ax
        mov     ss, ax
        mov     sp, $1000
        push    cs
        pop     ds
}

; Финализация для определения размера BIOS
macro final {

        times   ((maxsize - 16) - $) db 0
        jmp     (0x10000 - maxsize/16) : begin
        times   (maxsize - $) db 0xFF
}

; ------------------------------------------------------------------------------

; Процедура вызова функции очистки экрана
macro clear a {

        mov     ax, a
        call    cls
}
