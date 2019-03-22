prefix=@prefix@
datarootdir=@datarootdir@
exec_prefix=@exec_prefix@
bindir=@bindir@

all: evmtest.1

evmtest.1:
	asciidoc -d manpage -b docbook -o evmtest.1.xsl README
	asciidoc INSTALL
	xsltproc --nonet -o $@ $(MANPAGE_DOCBOOK_XSL) evmtest.1.xsl
	asciidoc -o evmtest.html README
	rm -f evmtest.1.xsl
install:
	install -m 755 evmtest $(bindir)
	install -d $(datarootdir)/evmtest/files/
	install -d $(datarootdir)/evmtest/tests/
	install -D $$(find ./files/ -not -type d)  $(datarootdir)/evmtest/files/
	install -D ./tests/* $(datarootdir)/evmtest/tests/
	cp evmtest.1 $(datarootdir)/man/man1
	mandb -q

.PHONY: install evmtest.1
