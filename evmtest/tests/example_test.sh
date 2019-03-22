#!/bin/bash

# This is an example test for documentation purposes.
# This test describes the outline of evmtest test files.

# Author: David Jacobson <davidj@linux.ibm.com>

TEST="example_test"
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )/.."
source "$ROOT"/files/common.sh
VERBOSE=0



usage () {
	echo ""
	echo "example_test -e <example_file> [-vh]"
	echo ""
	echo "	This is an example of how to structure an evmtest"
	echo ""
	echo "  -e	<example_file>"
	echo "  -h	Display this help message"
	echo "  -v	Verbose logging"
	echo ""
}



parse_args () {
	TEMP=$(getopt -o 'e:hv' -n 'example_test' -- "$@")
	eval set -- "$TEMP"
	while true ; do
		case "$1" in
			-h) usage; exit 0 ; shift;;
			-e) EXAMPLE_FILE=$2; shift 2;;
			-v) VERBOSE=1; shift;;
			--) shift; break;;
			*) echo "[*] Unrecognized option $1"; exit 1 ;;
		esac
	done

	if [ -z "$EXAMPLE_FILE" ]; then
		usage
		exit 1
	fi
}

# Define what needs to be tested as a function
check_file_exists () {
	if [ -e "$EXAMPLE_FILE" ]; then
		v_out "Example file exists"
	else
		fail "Example file not found"
	fi
}

# The two options are: EVMTEST_forbid_root and EVMTEST_require_root
EVMTEST_forbid_root

echo "[*] Starting test: $TEST"
parse_args "$@"
check_file_exists
passed
