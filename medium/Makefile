NAME=minesweeper

all: minesweeper

clean:
	rm -rf minesweeper minesweeper.o

minesweeper: minesweeper.asm
	nasm -f elf minesweeper.asm
	gcc -g -m32 -o minesweeper minesweeper.o /usr/local/share/csc314/driver.c /usr/local/share/csc314/asm_io.o
