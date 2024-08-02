
        ; BIOS находится в $F000 : $0000
        org     $0000

        ; Инициализация регистров
        cld
        cli
        mov     ax, cs
        mov     ds, ax
        mov     es, ax
        xor     ax, ax
        mov     ss, ax
        mov     sp, ax

        ; Очистка экрана и вывод приветственной строки
        mov     ax, 0x0720
        call    cls

        ; Очистка BDA
        xor     ax, ax
        mov     es, ax
        xor     di, di
        mov     cx, (2*256 + 128)
        rep     stosw

        ; Копирование BDA ($40:0)
        mov     si, bios_data
        mov     di, $400
        mov     cx, bda_actual_size
        rep     movsb

        ; Set pointer to INT 41 table for hard disk
        ; Set up last 16 bytes of memory, including boot jump, BIOS date, machine ID byte

        ; $00-$0F
        mov     si, int_table
        xor     di, di
        mov     cx, $10
@@:     movsw
        mov     ax, cs
        stosw
        loop    @b

        ; $10-$1F Специальный случай ROMBIOS
        mov     cx, $10
        xor     dx, dx
@@:     mov     ax, dx
        stosw
        mov     ax, $ffff
        stosw
        inc     dx
        loop    @b

        ; $70-$7F
        mov     cx, 8
        mov     di, $70 * 4
@@:     movsw
        mov     ax, cs
        stosw
        loop    @b

        ; Set up some I/O ports, between 0 and FFF. Most of them we set to 0xFF, to indicate no device present
        ; $61, $60, $64, $40, $42, $3B8, $3DA, $3BA, $3B8, $3BC, $62

        ; Get initial RTC value

        ; Выдать на экран строку
        mov     si, bioscopylefts
        call    print

        ; Загрузка Boot Sector
        mov	    ax, 0x0201
        mov	    dh, 0
        mov	    dl, $00         ; boot = Floppy Disk
        mov	    cx, 1
        mov	    bx, 0x7c00
        int     $13
        mov     si, disk_error_msg
        jc      panic

        ; Проверка магической константы
        xor     ax, ax
        mov     ds, ax
        mov     ss, ax
        cmp     [$7DFE], word $AA55
        jne     panic

        xor     ax, ax
        xor     cx, cx
        xor     bx, bx
        xor     si, si
        xor     di, di
        xor     bp, bp
        mov     sp, $7C00        
        sti
        jmp     $0 : $7C00 ; На выходе DL=0, загружено с флоппи

panic:  mov     ax, cs
        mov     ds, ax
        call    print
        jmp     $

include "misc.asm"
include "const.asm"
include "bda.asm"
include "irq.asm"
