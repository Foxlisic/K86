all: pgm
pgm:
	quartus_pgm -m jtag -o "p;output_files/marsohod2.sof"
syn:
	quartus_map --read_settings_files=on  --write_settings_files=off marsohod2 -c marsohod2
	quartus_fit --read_settings_files=off --write_settings_files=off marsohod2 -c marsohod2
	quartus_asm --read_settings_files=on  --write_settings_files=off marsohod2 -c marsohod2
	make pgm
cdb:
	quartus_cdb marsohod2 -c marsohod2 --update_mif
	quartus_asm --read_settings_files=on --write_settings_files=off marsohod2 -c marsohod2
clean:
	rm -rf db incremental_db simulation timing greybox_tmp *.jdi *.pof *.sld *.rpt *.summary *.sof *.done *.pin *.qws *.bak *.smsg *.qws *.vcd *.qqq *.jic *.map .qsys_edit undo_redo.txt PLLJ_PLLSPE_INFO.txt c5_pin_model_dump.txt output_files

