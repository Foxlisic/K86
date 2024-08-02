
; Особый BIOS, который имитирует крутой BIOS, но на самом деле это
; такой жесткий примитив, о котором вслух не говорят

        org     0xc000
        macro   brk { xchg bx, bx }
        
include "inc/equ.asm"           

bios_entry:

        ; Выполнить очистку экрана
        mov     sp, $c000
        mov     ax, $0720
        call    CMD_CLS                
        call    INIT    
        mov     bp, sGreets
        call    PRINT
        
        brk
        mov     si, T
        mov     cx, 32
        mov     di, O
        call    ATOI
        
T:      db '65536',0        
O:      dd 0        
    
; -----------------------------
@@:     call    GETCH        
        call    PRNCHR
        jmp     @b

include "inc/init.asm"        
include "inc/print.asm"        
include "inc/const.asm"        
include "inc/keyb.asm"        
include "inc/numeric.asm"        
       
; ----------------------------------------------------------------------       
        db      (0xFFF0 - $) dup 0x00       ; Unused
; ----------------------------------------------------------------------

F000_entry:

        jmp     bios_entry 
        db      (0x10000 - $) dup 0x00
        
