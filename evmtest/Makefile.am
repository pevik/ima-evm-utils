prefix=@prefix@
datarootdir=@datarootdir@
exec_prefix=@exec_prefix@
bindir=@bindir@

all: src evmtest.1

evmtest.1:
	asciidoc -d manpage -b docbook -o evmtest.1.xsl README
	asciidoc INSTALL
	xsltproc --nonet -o $@ $(MANPAGE_DOCBOOK_XSL) evmtest.1.xsl
	asciidoc -o evmtest.html README
	rm -f evmtest.1.xsl
src:
	cd src && make

install: src
	install -m 755 evmtest $(bindir)
	install -d $(datarootdir)/evmtest/files/
	install -d $(datarootdir)/evmtest/files/policies
	install -d $(datarootdir)/evmtest/tests/
	install -D \
	$$(find ./files/ -not -type d -not -path "./files/policies/*")  \
	$(datarootdir)/evmtest/files/
	install -D ./tests/* $(datarootdir)/evmtest/tests/
	install -D ./files/policies/* $(datarootdir)/evmtest/files/policies/
	cp ./src/basic_mod.ko $(datarootdir)/evmtest/files/
	cp ./src/basic_modload $(datarootdir)/evmtest/files
	cp evmtest.1 $(datarootdir)/man/man1
	mandb -q

.PHONY: src install evmtest.1
