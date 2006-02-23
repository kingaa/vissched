INSTALLDIR = $(HOME)

CC = gcc
CFLAGS = -O4 -Wall
LDLIBS = -lm

vissched:

%: %.c
	$(CC) $(CFLAGS) $*.c $(LDLIBS) -o $*

