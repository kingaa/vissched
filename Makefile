INSTALLDIR = www

RM = rm -f
CP = cp
INSTALL = install
CC = gcc
CFLAGS = -O4
LDLIBS = -lm

FILES = README.md styley.css input.csv VisSched.pm

default: $(FILES) vissched index.pl

index.cgi: index.pl

install: default
	mkdir -p --mode=0755 $(INSTALLDIR)
	$(INSTALL) --mode=0755 index.pl vissched $(INSTALLDIR)
	$(INSTALL) --mode=0644 $(FILES) $(INSTALLDIR)

%: %.c
	$(CC) $(CFLAGS) $*.c $(LDLIBS) -o $*

clean:
	$(RM) vissched
