# Makefile for the Motorola 6801/6803 lilbug monitor
# ncherry@linuxha.com 2023/01/04

all:	lilbug.s19

lilbug.s19: lilbug.p
	p2hex +5 -F Moto -r \$$-\$$ lilbug.p lilbug.s19
	ls
	srec_info lilbug.s19

lilbug.lst: lilbug.asm lilbug.inc ascii.inc
	asl -i . -D DEF9600 -L lilbug.asm

lilbug.p: lilbug.asm lilbug.inc ascii.inc
	asl -i . -D DEF9600 -L lilbug.asm

clean:
	rm -f lilbug.lst lilbug.p foo bar *~ lilbug.bin lilbug.hex lilbug.s19 dstfile.srec lilbug.srec
	echo Done

# # Assemble and convert to s19
# asl -i . -D DEF9600 -L lilbug.asm
# p2hex +5 -F Moto -r \$-\$ lilbug.p lilbug.s19
# # Not sure if the is the best way but it does work
# # Fill E000-F7FF with FF and append lilbug.s19
# srec_cat '(' -generate 0xE000 0xF800 --constant 0xFF ')' ~/lilbug.s19 -o dstfile.srec
# # convert the s19 to binary @ 0000
# srec_cat  dstfile.srec -offset -0xE000 -o lilbug.bin -binary
# # Use 2864A works for SEEQ and AT28C64-15 Note this automatically erases the chip
# minipro -p 28C64A -w lilbug.bin -y

burn: lilbug.s19
	srec_cat '(' -generate 0xE000 0xF800 --constant 0xFF ')' lilbug.s19 -o lilbug.srec
	srec_cat  lilbug.srec -offset -0xE000 -o lilbug.bin -binary
	@# We don't need sudo as we've fixed the device permission in the udev files
	minipro -p 28C64A -w lilbug.bin -y
