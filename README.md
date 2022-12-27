# lilbug for the Liebert Challenger 2 HVAC controller
Motorola's lilbug debugger for the MC6801/6803 processor. Assembled with [asl](https://github.com/linuxha/asl).

## Description
I didn't write the lilbug monitor, that would be someone at Motorola and the best I could find was this in the lilbug.asm: COMPILED APR 78 BY DIAMOND LIL FOR M6801. I also have Peter Stark's HumBug (hb7500) monitor for the Tandy MC-10 Color Computer. It also had a 6801/6803 processor. I have not yet integrated that into this ROM monitor. I grew up with systems that had ROM monitors (SWTPC, Gimix, AIM, Z80 Starter kit, Atari 800xl with Omnimon). They were a great way to understand how things worked.

What I have done so far is to reformat lilbug, assemble it and burned it to an EPROM (EEPROM -28C64). I hated the indentation so I reformatted it to make it more readable. I understand why it is that way. I started in this business in the late 70's but the old formatting was crude and offensive to my programmers sensibilities. I've also added an include (lilbug.inc) which contains some asl macros and the equates that were in the original lilbug.asm. I am able to use these files to assemble the lilbug monitor to a binary (and s19 file).

## Background
I have a unique makerspace ([Computer Deconstrution Lab](https://compdecon.github.io)) that shares it's location with a [Vintage Computer Museum](https://vcfed.org) (VCFed, on the National Historic Site of Camp Evans at [InfoAge](https://www.infoage.org/)). A non historic component, a Liebert Challenger 2 HVAC unit needed to be removed from the makerspace. This HVAC unit had been replaced a long time ago but this hulk of metal was taking up space which could be made better use with the HVAC's removal. After removing the unit and recycling most of it I decided to do the same with the original controller board. The board contained a Motorola MC6801 processor and I happen to like the Motorola family of processors. I began reverse engineering the board and discovered that it contains 1K of static RAM, internal 128 Bytes of RAM, 3 external devices to write to (0x4000, 0x6000, & 0x8000) and 1 external device to read from (0xA000). There is also P1 of the MC6801. I'm still decoding that.

With a little hacking I've added 8K of RAM at 0xC000 (originally P8 ROM) and the lilbug code at 0xE000 (0xf800 - P9 ROM). I'm still trying to figure out how to write to the various LEDs and 7 Segment display. But I think I should be able to write some ASM code to handle that. Using lilbug to hack the rest of the board. The various TTL chips give hints (serial to 8 bits, 2to4 decode, 4to10 BCD decode, etc.).

I must say it's been fun playing with the board and it should make an interesting display piece in the makerspace.

![alt text](https://github.com/linuxha/lilbug/blob/main/liebert-controller-640x319.png?raw=true "Liebert controller board")

Most of those connectors probably won't be used as they went to high powered controls (208 3-phase) and low powered sensors. I don't have any schematics

# f9dasm

After using my TL688 II+ and [Minipro](https://gitlab.com/DavidGriffith/minipro) - EPROM Burner to read the 2 ROM (Intel 2764P) I used the [f9dasm](https://github.com/linuxha/f9dasm) disassembler on the Liebert ROMs. First I cat'd liebert-P8.bin and liebert-P9.bin into liebert-P8nP9.bin. The ran the command line:
```
```
I used this info file:
```
****************************************
FILE MC6803-P8nP9.bin C000
OPTION begin C000
OPTION noflex
OPTION 6801
OPTION asc
****************************************
INCLUDE equ.info
INCLUDE data.info
INCLUDE irq.info
```
I ran f9dasm several times filling in the blanks. I created labels for the strings, MC6801 equates, interrupt vectors, data sections, etc. It's still a work in progress. Here's my f9dasm command line:

```
f9dasm -info liebert.info -out liebert.asm
```

# Reverse engineering

First note that I really don't need to disassemble the Liebert ROMs. It just makes figuring out the I/O somewhat easier. There are a lot of TTL support chips between the processor and things like the LEDs and I don't have a schematic. Also the Lilbug monitor makes it easy to load code into RAM and execute it. So I can take what I've learned and poke around.

Every usefull computer basically has I/O, RAM and ROM. Some things are obvious, usually the processor, the RAM and the ROM. Older controllers such as the Challenger are generally easier to reverse engineer. You start with the processor. You'll know certain things about the processor such as pinout, 8 bits of data, 16 bits addressing (64K) and where it starts at reset. After the processor details you look at the board and the chips. This board didn't have custom chips such as PALs or FPGA just lots of CMOS and TTL chips. You look up chips data sheets and you know the pinouts and the chips purpose. One important thing is you need to have some chip decode the I/O. That's the job of the 74LS138 (3 to 8 decode). If you trace the pinouts you find that Address lines A13 thru A15 are attached to the 74LS138 so we can see that each select represents an address range of 8K. This matches with the ROMS which are each 8K. We know that there must be one ROM at E000 so a guess that P8 lives there. I can combine the two ROMS and begin disassembly. The first few passes will give you lots of junk but you can start by looking at the interrupt vectors and seeing where they trace to. Also look for any ASCII strings and odd FCC or FCB statements in the middle of code.

# Hardware Notes

- MC6801 in Mode 2 (External I/O, internal 128 bytes of RAM)
  - was 4.0 MHz xtal (very odd baud rate of 78xx baud)
  - switched to 4.9152MHz (gives 300, 1200 and 9600 baud)
- I/O at:
  - 0000 - 128 Bytes RAM
  - 2000 - 1024 Bytes static RAM
  - 4000 - I/O - write (not read)
  - 6000 - 374, 8 Motor SCRs 
  - 8000 - I/O - write (not read)
  - A000 - I/O - read (not written to)
  - C000 - 8K ROM <- Hack in 8K RAM
  - E000 - 8K ROM
- 8x LED (7442 - 4 to 10 BCD to Decimal decoder)
- 2x 7-segment displays (74164 - 8-Bit Parallel-Out A/B Serial in Shift Registers)
- 11x LEDs (7 red, 4 Green - front panel - 74164)
- DIPs (???)
- Serial RS485 (hacked for 5v TTL)



# Software Notes

- s0.sh - creates a new s0 record with the file name in it  (not used here yet)
- s9.sh - creates a new s9 record (not used here yet)

# Links

- [f9dasm](https://github.com/linuxha/f9dasm) - disassembler
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
