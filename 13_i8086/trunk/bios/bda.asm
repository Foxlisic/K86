bios_data:          ; $0040:0000
; http://stanislavs.org/helppc/bios_data_area.html
; ---------------------------------------------
com1addr            dw    0         ; 00
com2addr            dw    0         ; 02
com3addr            dw    0         ; 04
com4addr            dw    0         ; 06
lpt1addr            dw    0         ; 08
lpt2addr            dw    0         ; 0A
lpt3addr            dw    0         ; 0C
lpt4addr            dw    0         ; 0E

; http://stanislavs.org/helppc/int_11.html
equipment           dw    0x21      ; 10 

;  0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 1
; |F|E|D|C|B|A|9|8|7|6|5|4|3|2|1|0|  AX
;  | | | | | | | | | | | | | | | `---- IPL diskette installed
;  | | | | | | | | | | | | | | `----- math coprocessor
;  | | | | | | | | | | | | `-------- old PC system board RAM < 256K
;  | | | | | | | | | | | | | `----- pointing device installed (PS/2)
;  | | | | | | | | | | | | `------ not used on PS/2
;  | | | | | | | | | | `--------- initial video mode
;  | | | | | | | | `------------ # of diskette drives, less 1
;  | | | | | | | `------------- 0 if DMA installed
;  | | | | `------------------ number of serial ports
;  | | | `------------------- game adapter installed
;  | | `-------------------- unused, internal modem (PS/2)
;  `----------------------- number of printer ports

                    db    0         ; 12
memsize             dw    0x280     ; 13 640 kb
                    db    0         ; 15
                    db    0         ; 16
keyflags1           db    0         ; 17
keyflags2           db    0         ; 18
                    db    0         ; 19
kbbuf_head          dw    kbbuf - bios_data ; 1A
kbbuf_tail          dw    kbbuf - bios_data ; 1C
kbbuf:              times 32 db 'X' ; 1E
drivecal            db    0         ; 3E
diskmotor           db    0         ; 3F
motorshutoff        db    0x07      ; 40
disk_laststatus     db    0         ; 41
                    times 7 db 0    ; 48
                    
; http://stanislavs.org/helppc/int_10-0.html                    
vidmode             db    0x03      ; 49 Видеорежим
vid_cols            dw    80        ; 4A
page_size           dw    0x1000    ; 4C
                    dw    0         ; 4E
curpos_x            db    0         ; 50
curpos_y            db    0         ; 51
                    times 7 dw 0    ; 52
cur_v_end           db    7         ; 60
cur_v_start         db    6         ; 61
disp_page           db    0         ; 62
crtport             dw    0x3d4     ; 63
                    db    10        ; 65
                    db    0         ; 66
                    times 5 db 0    ; 67
clk_dtimer          dd    0         ; 6C
clk_rollover        db    0         ; 70
ctrl_break          db    0         ; 71
soft_rst_flg        dw    0x1234    ; 72
                    db    0         ; 74
num_hd              db    0         ; 75
                    db    0         ; 76
                    db    0         ; 77
                    dd    0         ; 78
                    dd    0         ; 7C
kbbuf_start_ptr     dw    0x001e    ; 80
kbbuf_end_ptr       dw    0x003e    ; 82
vid_rows            db    25        ; $40:84
                    db    0         ; 85
                    db    0         ; 86
vidmode_opt         db    0 ; 0x70  ; 87
                    db    0 ; 0x89  ; 88
                    db    0 ; 0x51  ; 89
                    db    0 ; 0x0c  ; 8A
                    db    0         ; 8B
                    db    0         ; 8C
                    db    0         ; 8D
                    db    0         ; 8E
                    db    0         ; 8F
                    db    0         ; 90
                    db    0         ; 91
                    db    0         ; 92
                    db    0         ; 93
                    db    0         ; 94
                    db    0         ; 95
kb_mode             db    0         ; 96
kb_led              db    0         ; 97
                    db    0         ; 98
                    db    0         ; 99
                    db    0         ; 9A
                    db    0         ; 9B
boot_device         db    0         ; 9C
crt_curpos_x        db    0         ; 9D
crt_curpos_y        db    0         ; 9E
key_now_down        db    0         ; 9F
next_key_fn         db    0         ; A0
cursor_visible      db    1         ; A1
escape_flag_last    db    0         ; A2
next_key_alt        db    0         ; A3 
escape_flag         db    0         ; A4
notranslate_flg     db    0         ; A5
this_keystroke      db    0         ; A6
this_keystroke_ext  db    0         ; A7
timer0_freq         dw    0xffff    ; A8 PIT channel 0 (55ms)
timer2_freq         dw    0         ; AA PIT channel 2
cga_vmode           db    0         ; AC
vmem_offset         dw    0         ; AD Video RAM offset

bda_actual_size     = $ - bios_data
