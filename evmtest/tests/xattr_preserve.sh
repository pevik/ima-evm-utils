#!/bin/bash
# Author: David Jacobson <davidj@linux.ibm.com>
TEST="xattr_preserve"
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )/.."
source "$ROOT"/files/common.sh

VERBOSE=0
# This test ensures that extended file attributes are preserved when a file is
# moved with the correct flag

usage (){
	echo ""
	echo "xattr_preserve [-hv]"
	echo ""
	echo "This test requires root privileges to write security xattrs"
	echo ""
	echo "	This test ensures that extended file attributes (specifically"
	echo "	security.ima labels) are preserved when copying"
	echo "Options"
	echo "  -h	Display this help message"
	echo "  -v	Verbose logging"
}

parse_args () {
	TEMP=$(getopt -o 'hv' -n 'xattr_preserve' -- "$@")
	eval set -- "$TEMP"

	while true ; do
		case "$1" in
		-h) usage; exit; shift;;
		-v) VERBOSE=1; shift;;
		--) shift; break;;
		*) echo "[*] Unrecognized option $1"; exit 1;;
		esac
	done
}

check_xattr_preserve () {
	LOCATION_1=$(mktemp)
	LOCATION_2=$(mktemp -u) # Doesn't create the file

	v_out "Creating and labeling file $LOCATION_1..."

	evmctl ima_hash "$LOCATION_1"

	initial_ima_label=$(getfattr --absolute-names -n security.ima \
			"$LOCATION_1")
	initial_hash=$(echo "$initial_ima_label" | awk -F '=' '{print $2}')
	if printf '%s' "$initial_ima_label" | grep -E -q "security.ima"; then
		v_out "Found hash on initial file... "
	else
		fail "Hash not found on initial file"
	fi

	initial_hash=$(echo "$initial_ima_label" | awk -F '=' '{print $2}')

	v_out "Copying file to $LOCATION_2..."
	cp --preserve=xattr "$LOCATION_1" "$LOCATION_2"
	v_out "Checking if extended attribute has been preserved..."


	second_ima_label=$(getfattr --absolute-names -n security.ima \
			"$LOCATION_2")
	second_hash=$(echo "$second_ima_label" | awk -F '=' '{print $2}')
	if [ "$initial_hash" != "$second_hash" ]; then
		fail "security.ima xattr was not preserved!"
	else
		v_out "Extended attribute was preserved during copy"
	fi
}

cleanup () {
	v_out "Cleaning up..."
	rm "$LOCATION_1" "$LOCATION_2"
}

EVMTEST_require_root
echo "[*] Starting test: $TEST"
check_xattr_preserve
cleanup
passed
