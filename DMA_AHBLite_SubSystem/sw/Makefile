
# Makefile for bare-metal PicoRV32 C programs
#
# This file expects a C program "code/main.c" provided by the user
# plus an assembly language startup program "code/start.c"

# Give the user some easy overrides for local configuration quirks.
# If you change one of these and it breaks, then you get to keep both pieces.
SHELL = bash
PYTHON = python3

# Start wih no optimisation - better for understanding the code
OPTIMISATION = 0

SOFTWARE_OBJS = code/main.o code/crt.o code/start.o
GCC_WARNS  = -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings
GCC_WARNS += -Wredundant-decls -Wstrict-prototypes -pedantic # -Wconversion
TOOLCHAIN_PREFIX = /opt/cad/soft/riscv32i/bin/riscv32-unknown-elf-
HEX2V = /opt/cad/bim/c/hex2v/hex2v_soc

# Define optimisation level here
# Start wih no optimisation - better for understanding the code
OPT = -O0


# this controls the instruction set supported by the PicoRV32
# the possible options are:
#
#   rv32i       Integer
#   rv32im      Integer + Hardware multiply and divide
#   rv32ic      Integer + Compressed instruction set
#   rv32imc     Integer + Hardware multiply and divide + Compressed instruction set
#
# (note that the parameters of the PicoRV32 core need to be
#  changed in order to support anything other than rv32i)
#
RVARCH = rv32i


#
# makefile rules
#

all: $(SOFTWARE_OBJS) code.elf code.lst code.ihex code.hex code.vmem


code.elf: $(SOFTWARE_OBJS) soc.ld
	$(TOOLCHAIN_PREFIX)gcc $(OPT) -mabi=ilp32 -march=$(RVARCH) -ffreestanding -nostdlib -o $@ \
		-Wl,--build-id=none,-Bstatic,-T,soc.ld,-Map,code.map,--strip-debug \
		$(SOFTWARE_OBJS) -lgcc
	chmod -x $@

%.o: %.c
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=$(RVARCH) $(OPT) --std=c99 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $<

%.o: %.s
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=$(RVARCH) $(OPT) --std=c99 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $<


%.s: %.c
	$(TOOLCHAIN_PREFIX)gcc -S -c -mabi=ilp32 -march=$(RVARCH) $(OPT) --std=c99 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $<

%.ihex: %.elf
	$(TOOLCHAIN_PREFIX)objcopy -O ihex $< $@

%.lst: %.elf
	$(TOOLCHAIN_PREFIX)objdump -d $< > $@


# convert the Intel format hex file to a 4 byte per line format for $readmemh
%.hex: %.ihex
	$(HEX2V) $< 4 > $@

# convert the Intel format hex file to a verilog style memory assignment
# note that the .hex file is always updated when a new .vmem file is created
%.vmem: %.ihex %.hex
	$(HEX2V) $< 4 memory > $@


clean:
	rm -vrf $(SOFTWARE_OBJS) \
		code.elf code.bin code.hex code.ihex code.map code.lst
