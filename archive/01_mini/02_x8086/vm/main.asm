
WORK_SEGMENT        EQU 0x0800 ; 0xC000 - PRODUCTION

CURRENT_CURSOR_X    EQU 0x0400
CURRENT_CURSOR_Y    EQU 0x0402

; ----------------------------------------------------------------------

        org     0000h
        
        macro   brk { xchg bx, bx }

        cli
        cld

        xor     ax, ax
        mov     es, ax
        mov     ds, ax
        call    Initial_Data  
        call    Interrupt_Setup

        ; Очистить экран
        mov     ax, 0xB800
        mov     es, ax

        xor     di, di
        mov     cx, 2000
        mov     ax, 0x0700
        rep     stosw
    
        ;brk
        
        mov     si, BiosCopyrights
        call    Print
        
        jmp     $
    
; ----------------------------------------------------------------------
Print:

        lodsb
        test    al, al
        je      .exit
        mov     ah, 0x0E
        int     10h
        jmp     Print
.exit:  ret        
        
; Video Interrupt
; ----------------------------------------------------------------------
Int10_TeletypeChar:

        push    ax bx ds es
        xor     bx, bx
        mov     ds, bx
        mov     bx, 0xB800
        mov     es, bx
        
        ; Print Char teletype mode
        cmp     ah, 0x0E
        je      .print_char
        jmp     .exit
        
        
.print_char:

        mov     di, [CURRENT_CURSOR_Y]
        shl     di, 5
        mov     bx, di
        shl     di, 2
        add     bx, di
        add     di, [CURRENT_CURSOR_X]
        add     di, di
        mov     ah, 0x07                    ; COLOR=7, BG=0
        stosw
        
        ; Сдвиг следующего символа
        inc     word [CURRENT_CURSOR_X]
        cmp     word [CURRENT_CURSOR_X], 80
        ; ...

.exit:

        pop     es ds bx ax
        iret
        
; Disk Interrupt
; ----------------------------------------------------------------------
Int13_DiskService:

        iret

irq_DivideZero:
irq_SingleStep:
irq_NonMasking:
irq_Breakpoint:
irq_OverflowTp:
    
        iret

; Установка прерываний
; ----------------------------------------------------------------------
Interrupt_Setup:

        mov     ax, WORK_SEGMENT
        mov     ds, ax

        ; Очистить таблицу прерываний
        mov     cx, 256 * 2
        xor     di, di
@@:     rep     stosw

        mov     cx, 20                  ; Количество полезных прерываний
        mov     si, .Listing
        xor     di, di
        mov     ax, ds
@@:     movsw
        stosw
        loop    @b                
        ret        
      
.Listing: ; http://stanislavs.org/helppc/int_table.html

        ; IRQ Routines
        dw      irq_DivideZero      ; 00 Divide by zero
        dw      irq_SingleStep      ; 01 Single step
        dw      irq_NonMasking      ; 02 Non-maskable  (NMI)
        dw      irq_Breakpoint      ; 03 Breakpoint
        dw      irq_OverflowTp      ; 04 Overflow trap
        dw      0                   ; 05 Print Screent
        dw      0                   ; 06 
        dw      0                   ; 07 
        dw      0                   ; 08 Timer (55ms intervals, 18.2 per second)
        dw      0                   ; 09 Keyboard
        dw      0                   ; 0A 
        dw      0                   ; 0B COM2 or COM4
        dw      0                   ; 0C COM1 or COM3
        dw      0                   ; 0D Fixed Disk
        dw      0                   ; 0E Floppy Disk
        dw      0                   ; 0F 
        
        ; Список прерываний BIOS
        dw      Int10_TeletypeChar  ; 10
        dw      0                   ; 11
        dw      0                   ; 12
        dw      Int13_DiskService   ; 13
         
; Инициализация
; ----------------------------------------------------------------------        
Initial_Data:

        mov     [CURRENT_CURSOR_X], word 0
        mov     [CURRENT_CURSOR_Y], word 0
        ret
         
; ----------------------------------------------------------------------
BiosCopyrights:
    
        db "Tiny-8086 Microprocessor by V.Foxtail", 0
        
