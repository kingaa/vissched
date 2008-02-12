INSTALLDIR = /var/www/html/vissched

RM = rm -f
CP = cp
INSTALL = install
CC = gcc
CFLAGS = -O4 -Wall
LDLIBS = -lm

FILES = styley.css .htaccess README.html input.csv index.pl VisSched.pm vissched.c

default: $(FILES) vissched index.cgi

index.cgi: index.pl

install: default
	$(INSTALL) index.cgi vissched $(FILES) $(INSTALLDIR)

%: %.c
	$(CC) $(CFLAGS) $*.c $(LDLIBS) -o $*

%.cgi: %.pl
	perlcc -B $^ -o $@

clean:
	$(RM) vissched index.cgi
