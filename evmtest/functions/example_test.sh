#!/bin/bash
# Author: David Jacobson <davidj@linux.ibm.com>
TEST="example_test"

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )/.."
source $ROOT/files/common.sh
VERBOSE=0

# This is an example test for documentation purposes.
# This test describes the outline of evmtest test files.

# Each file starts with a $TEST variable that gives the name of the test.
# The next line should have the test author.
# There are then the three bootstrap lines that follow
# The first finds the current location of the script, so the needed files can
# be found relative to it. The second line imports functions and variables
# that are useful for writing tests. The third sets the output to silent.
# After that, there is a 2-3 line description of the test.
# Tests which require root should start with r_

usage () {
	echo ""
	echo "example_test -e <example_file> [-vh]"
	echo ""
	echo "  This test is an example of how to structure an evmtest."
	echo ""
	echo "  -e,--example_file  Any file"
	echo "  -v,--verbose    Verbose testing"
	echo "  -h,--help       Displays this help message"
	echo ""
}

# Define the usage
TEMP=`getopt -o 'e:hv' -l 'example_file:,help,verbose' -n\
	'example_test' -- "$@"`
# letter followed by : means an argument is taken
eval set -- "$TEMP"
while true ; do
	case "$1" in
		-h|--help) usage; exit 0 ; shift;;
		-e|--example_file) EXAMPLE_FILE=$2; shift 2;;
		-v|--verbose)   VERBOSE=1; shift;;
		--) shift; break;;
		*) echo "[*] Unrecognized option $1"; exit 1 ;;
	esac
done

# All arguments can be parsed like the above.
# To require an argument, check that it has been defined. If it has not,
# display usage and exit.
if [[ -z $EXAMPLE_FILE ]]; then
	usage
	exit 1
fi

# Define how the test should be run:
# The two options are: EVMTEST_forbid_root and EVMTEST_require_root
EVMTEST_forbid_root

# This function outputs that the test is starting:
begin

# Do whatever testing needs to be done
if [[ -e $EXAMPLE_FILE ]]; then
	# Output data for logging / debugging:
	# [*] = Informative
	# [!] = Attention Required
	v_out "Example file exists"
else
	# Some condition failed, fail the test
	fail "Example file does not exist"
fi

# If all has gone well until here - the test has passed
passed
