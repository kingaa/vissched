INSTALLDIR = /var/www/html/vissched
CONFDIR = /etc/apache2/conf-available

RM = rm -f
CP = cp
INSTALL = install
CC = gcc
CFLAGS = -O4
LDLIBS = -lm

FILES = doc.html styley.css input.csv VisSched.pm vissched.c

default: $(FILES) vissched index.pl

install: default vissched.conf
	mkdir -p --mode=0755 $(INSTALLDIR)
	$(INSTALL) --mode=0755 index.pl vissched $(INSTALLDIR)
	$(INSTALL) --mode=0644 $(FILES) $(INSTALLDIR)
	>vissched.log
	$(INSTALL) --mode=0666 vissched.log $(INSTALLDIR)
	$(INSTALL) --mode=0600 vissched.conf $(CONFDIR)
	a2enconf vissched

uninstall:
	a2disconf vissched
	$(RM) -r $(INSTALLDIR)
	$(RM) $(CONFDIR)/vissched.conf

%: %.c
	$(CC) $(CFLAGS) $*.c $(LDLIBS) -o $*

clean:
	$(RM) vissched
