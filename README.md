# lilbug
Motorola's lilbug debugger for the MC6801/6803 processor. Assembled with [asl](https://github.com/linuxha/asl).

## Description
I didn't write the lilbug monitor, that would be someone at Motorola and the best I could find was this in the lilbug.asm: COMPILED APR 78 BY DIAMOND LIL FOR M6801. I also have Peter Stark's HumBug (hb7500) monitor for the Tandy MC-10 Color Computer. It also had a 6801/6803 processor. I have not yet integrated that into this ROM monitor. I grew up with systems that had ROM monitors (SWTPC, Gimix, AIM, Z80 Starter kit, Atari 800xl with Omnimon). They were a great way to understand how things worked.

What I have done so far is to reformat lilbug, assemble it and burned it to an EPROM (EEPROM -28C64). I hated the indentation so I reformatted it to make it more readable. I understand why it is that way. I started in this business in the late 70's but the old formatting was crude and offensive to my programmers sensibilities. I've also added an include (lilbug.inc) which contains some asl macros and the equates that were in the original lilbug.asm. I am able to use these files to assemble the lilbug monitor to a binary (and s19 file).

## Background
I have a unique makerspace ([Computer Deconstrution Lab](https://compdecon.github.io)) that shares it's location with a [Vintage Computer Museum](https://vcfed.org) (VCFed, on the National Historic Site of Camp Evans at [InfoAge](https://www.infoage.org/)). A non historic component, a Liebert Challenger 2 HVAC unit needed to be removed from the makerspace. This HVAC unit had been replaced a long time ago but this hulk of metal was taking up space which could be made better use with the HVAC's removal. After removing the unit and recycling most of it I decided to same the original controller board. The board contained a Motorola MC6801 processor and I happen to like the Motorola family of processors. I began reverse engineering the board and discovered that it contains 1K of static RAM, internal 128 Bytes of RAM, 3 external devices to write to (0x4000, 0x6000, & 0x8000) and 1 external device to read from (0xA000). There is also P1 of the MC6801. I'm still decoding that.

With a little hacking I've added 8K of RAM at 0xC000 (originally P8 ROM) and the lilbug code at 0xE000 (0xf800 - P9 ROM). I'm still trying to figure out how to write to the various LEDs and 7 Segment display. But I think I should be able to write some ASM code to handle that. Using lilbug to hack the rest of the board. The various TTL chips give hints (serial to 8 bits, 2to4 decode, 4to10 BCD decode, etc.).

I must say it's been fun playing with the board and it should make an interesting display piece in the makerspace.

![alt text](https://github.com/linuxha/lilbug/blob/main/liebert-controller-640x319.png?raw=true "Liebert controller board")

# Notes

- s0.sh - creates a new s0 record with the file name in it  (not used here yet)
- s9.sh - creates a new s9 record (not used here yet)

# Links

- [f9dasm](https://github.com/linuxha/f9dasm) - disassemble
- [asl](https://github.com/linuxha/asl) - Macro assembler
- [srec_examples](https://manpages.ubuntu.com/manpages/xenial/man1/srec_examples.1.html)
- [minipro](https://gitlab.com/DavidGriffith/minipro) - EPROM Burner

# Commands
```
lilbug

Default to 300 baud               (1.0 defaults to 300, 1.1 defaults to 9600)
HY to set it to 1200 baud
HI to set it to 9600 baud
really need to change this to 9600 as the default

assemble & burn

- lilbug.asm
- lilbug.inc
  
# DEF9600 set 9600 baud to the default speed and changes the version to 1.1
# I'll clean that up later to be 1.0.1 (semantic versioning) when I modify
# the code to support the HD6303V1 (which has an additional interrupt)
asl -i . -D DEF9600 -L lilbug.asm
# SEE ALSO
#        plist(1), pbind(1), p2hex(1), p2bin(1)
# The +5 gets rid of the s5 record which minipro doesn't like
p2hex +5 -F Moto -r \$-\$ lilbug.p lilbug.s19

27512 = 64K (0x0 - 0xFFFF)
2764  =  8K (0x0 - 0x1FFF)

FFFF - F800 = 0x07FF (2K)
E000 - F7FF free (6K)

###
### Works
###
# Assemble and convert to s19
asl -i . -D DEF9600 -L lilbug.asm
p2hex +5 -F Moto -r \$-\$ lilbug.p lilbug.s19

# Not sure if the is the best way but it does work
# Fill E000-F7FF with FF and append lilbug.s19
srec_cat '(' -generate 0xE000 0xF800 --constant 0xFF ')' ~/lilbug.s19 -o dstfile.srec

# convert the s19 to binary @ 0000
srec_cat  dstfile.srec -offset -0xE000 -o lilbug.bin -binary

# TL866 II+ & Minipro
# Use 2864A, works for SEEQ and AT28C64-15 Note this automatically erases the chip
minipro -p 28C64A -w lilbug.bin -y
```

# License
Need to find the license for the Motorola lilbug monitor

My bash code s0.sh and s9.sh are GNU GPLv2.