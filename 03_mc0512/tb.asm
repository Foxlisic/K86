
        org     0
        mov     si, D1
        mov     di, D2
        scasw
        hlt
D1:     dw      $BAAD, $FACE
D2:     dw      $DEAD, $BEEF
