all: syn
syn:
	quartus_map --read_settings_files=on  --write_settings_files=off de0 -c de0
	quartus_fit --read_settings_files=off --write_settings_files=off de0 -c de0
	quartus_asm --read_settings_files=on  --write_settings_files=off de0 -c de0
pgm:
	quartus_pgm -m jtag -o "p;output_files/de0.sof"
cdb:
	quartus_cdb de0 -c de0 --update_mif
	quartus_asm --read_settings_files=on --write_settings_files=off de0 -c de0
	make pgm
sta:
	quartus_sta de0 -c de0
clean:
	rm -rf db incremental_db simulation timing greybox_tmp *.jdi *.pof *.sld *.rpt
	rm -rf *.summary *.sof *.done *.pin *.bak *.smsg *.qws *.vcd
	rm -rf *.gtkw *.qqq *.jic *.map .qsys_editundo_redo.txt PLLJ_PLLSPE_INFO.txt
	rm -rf c5_pin_model_dump.txt output_files obj_dir *.o *.elf *.lst *.qdf
