include "../macro.asm"
boot    1024

        clear   $0700
        jmp     $

include "../bios.asm"
final
