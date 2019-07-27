check_SCRIPTS =
TESTS = $(check_SCRIPTS)

check_SCRIPTS += ima_hash.test ima_verify.test ima_sign.test

# ima_verify depends on results of ima_hash
ima_verify.log: ima_sign.log

clean-local:
	-rm -f *.txt *.out *.sig *.sig2

distclean: distclean-keys
.PHONY: distclean-keys
distclean-keys:
	./gen-keys.sh clean
