
; ----------------------------------------------------------------------
; При загрузке BIOS, код бутсектора помещается в память
; по адресу [0000 : 7C00h]
; ----------------------------------------------------------------------

        macro   brk { xchg bx, bx }
        org     7C00h
        
        cli
        cld
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, 7BFEh        
        mov     ah, 42h
        mov     si, DAP_sector  ; BIOS DAP https://en.wikipedia.org/wiki/INT_13H
        int     13h

        ; Старт Protected Mode
        lgdt    [GDTR]
        mov     eax, cr0
        or      al, 1
        mov     cr0, eax
        jmp     0x18 : init_pm

GDTR:   ; Регистр глобальной дескрипторной таблицы
        dw 5*8 - 1          ; Лимит GDT (размер - 1)
        dd GDT              ; Линейный адрес GDT

GDT:    dw 0,      0,      0,     0      ; 00 NULL-дескриптор
        dw 0FFFFh, 0x8000, 9A00h, 0000h  ; 08 16-bit код
        dw 0FFFFh, 0x8000, 9200h, 0000h  ; 10 16-bit данные
        dw 0FFFFh, 0x0000, 9A00h, 000Fh  ; 18 16-bit временный код
        dw 0FFFFh, 0x0000, 9200h, 000Fh  ; 20 16-bit временные данные

DAP_sector:

        db      10h         ; +0 размер DAP (16 байт)
        db      00h         ; +1 не используется, должен быть 0
        dw      40h         ; +2 количество сектров для чтения (1)
        dw      8000h       ; +4 смещение : сегмент (0 : 7E00h)
        dw      0000h       ; +6 куда будет загружаться сектор (прямо за бутсектором сделал)
        dq      1           ; +8 номер сектора, который нужно загрузить с диска (64 битный)
                            ;    первый сектор = 0

init_pm:     

        ; Создать сегменты
        mov     ax, 0x20
        mov     es, ax
        mov     ds, ax
        mov     ss, ax
        mov     sp, 0

        ; Инициализация PDBR
        xor     eax, eax
        mov     di, 1000h
        mov     cx, 1024
        rep     stosd
        mov     [1000h], dword 2003h
        
        ; Разметка
        mov     eax, 3
        mov     di, 2000h
@@:     stosd
        add     eax,  1000h
        cmp     eax, 400003h
        jne     @b
        
        ; Разметка Paging
        mov     eax, 1000h
        mov     cr3, eax
        
        ; B000h(4*B) + 8000h(8*4) = 4Ch
        mov     [204Ch], dword 0B8003h
   
        mov     esi, 0x8000
        mov     edi, 0x8000 + 0xc000
        mov     cx, 16384 shr 2
@@:     mov     eax, [esi]
        mov     [edi], eax
        add     esi, 4
        add     edi, 4
        loop    @b
        
        ; Восстановить правильный сегмент
        mov     ax, 10h
        mov     ds, ax
        mov     ss, ax
        mov     es, ax

        mov     eax, cr0
        or      eax, 80000000h
        mov     cr0, eax

        ; Запуск эмуляции
        jmp     8 : 0xfff0      ; Здесь начинается BIOS
                            
        db      (7C00h + 510 - $) dup 0 ; Филлер
        dw      0AA55h
