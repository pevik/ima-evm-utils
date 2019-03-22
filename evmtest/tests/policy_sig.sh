#!/bin/bash
TEST="policy_sig"
# Author: David Jacobson <davidj@linux.ibm.com>

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )/.."
source "$ROOT"/files/common.sh

VERBOSE=0
POLICY_LOAD="$ROOT"/files/load_policy.sh
# This test validates that IMA measures and appraises policies.
usage() {
	echo ""
	echo "policy_sig -k <key> [-vh]"
	echo ""
	echo "  This test first loads a policy requiring all subsequent"
	echo "	policies to be signed, and verifies that only signed policies"
	echo "	may then be loaded."
	echo ""
	echo "  Loading policy rules requires root privilege. This test must be"
	echo "	executed as root."
	echo ""
	echo "  -k	The key for the certificate on the IMA keyring"
	echo "  -h	Display this help message"
	echo "  -v	Verbose logging"
}

parse_args () {
	TEMP=$(getopt -o 'k:hv' -n 'policy_sig' -- "$@")
	eval set -- "$TEMP"

	while true ; do
		case "$1" in
			-h) usage; exit 0; shift;;
			-k) IMA_KEY=$2; shift 2;;
			-v) VERBOSE=1; shift;;
			--) shift; break;;
			*) echo "[*] Unrecognized option $1"; exit 1 ;;
		esac
	done

	if [ -z "$IMA_KEY" ]; then
		usage
		exit 1
	fi

	if [ ! -f "$IMA_KEY" ]; then
		cleanup
		fail "Missing key"
	fi
}

load_signed_policy () {
	v_out "Signing policy with provided key..."
	if ! evmctl ima_sign -f "$POLICY_PATH" -k "$IMA_KEY" &>> /dev/null; then
		cleanup
		fail "Failed to sign policy - check key file"
	fi

	v_out "Loading policy..."
	if ! "$POLICY_LOAD" signed_policy &>> /dev/null; then
		cleanup
		fail "Failed to write policy. "
	fi
	v_out "Loaded"
}

load_unsigned_policy () {
	v_out "Attempting to load unsigned policy..."
	if "$POLICY_LOAD" unsigned_policy &>> /dev/null; then
		cleanup
		fail "Failed to reject unsigned policy"
	fi

	v_out "IMA Blocked unsigned policy"
}

load_unknown_key_policy () {
	v_out "Signing policy with invalid key..."
	evmctl ima_sign -f "$ROOT"/files/policies/unknown_signed_policy \
		-k "$ROOT"/files/unknown_privkey_ima.pem &>> /dev/null

	v_out "Attempting to load policy signed by invalid key..."
	if "$POLICY_LOAD" unknown_signed_policy &>> /dev/null; then
		cleanup
		fail "Failed to reject policy signed by unknown key"
	fi

	v_out "IMA blocked policy signed by unknown key"
}

cleanup () {
	v_out "Removing security.ima attribute from policies..."
	setfattr -x security.ima "$ROOT"/files/policies/unsigned_policy &>> \
		/dev/null
	setfattr -x security.ima "$ROOT"/files/policies/unknown_signed_policy \
		&>> /dev/null
	v_out "Done"
}

POLICY_PATH="$ROOT"/files/policies/signed_policy

EVMTEST_require_root
echo "[*] Starting test: $TEST"
parse_args "$@"
load_signed_policy
load_unsigned_policy
load_unknown_key_policy
cleanup
passed
