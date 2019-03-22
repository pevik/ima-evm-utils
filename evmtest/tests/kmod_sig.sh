#!/bin/bash
# Author: David Jacobson <davidj@linux.ibm.com>
TEST="kmod_sig"
BUILD_DIR=""
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )/.."
source "$ROOT"/files/common.sh

VERBOSE=0
# This test validates that IMA prevents the loading of unsigned
# kernel modules

# The boot command line option module.sig_enforce=1 is equivalent to
# compiling with CONFIG_MODULE_SIG_FORCE enabled.

usage(){
	echo ""
	echo "kmod_sig [-b build_directory] -k <ima_key> [-v]"
	echo "	This test verifies that IMA prevents the loading of an"
	echo "	unsigned kernel module with a policy appraising MODULE_CHECK"
	echo ""
	echo "	This test must be run as root"
	echo ""
	echo "	-b	The path to a kernel build dir"
	echo "	-k	IMA key"
	echo "	-v	Verbose logging"
	echo "	-h	Display this help message"
}

parse_args () {
	TEMP=$(getopt -o 'b:k:hv' -n 'kmod_sig' -- "$@")
	eval set -- "$TEMP"

	while true ; do
		case "$1" in
		-h) usage; exit 0 ;;
		-b) BUILD_DIR=$2; shift 2;;
		-k) IMA_KEY=$2; shift 2;;
		-v) VERBOSE=1; shift;;
		--) shift; break;;
		*) echo "[*] Unrecognized option $1"; exit 1 ;;
		esac
	done

	if [ -z "$IMA_KEY" ]; then
		echo "[!] Please provide an IMA key."
		usage
		exit 1
	fi
}


set_build_tree_location () {
	if [ -z "$BUILD_DIR" ]; then
		BUILD_DIR="/lib/modules/$(uname -r)/build"
		if [ ! -e "$BUILD_DIR" ]; then
			echo "[!] Could not find build tree. Specify with -b"
			exit 1
		else
			v_out "No build tree provided."\
			"Found - using: $(readlink -f "$BUILD_DIR")"
		fi
	fi


	if [ ! -d "$BUILD_DIR" ]; then
		fail "Could not find kernel build path"
	fi
}

check_key () {
	if [ ! -e "$IMA_KEY" ]; then
		fail "Could not find IMA key"
	fi
}

check_policy () {
	already_run="IMA policy already contains MODULE_CHECK"
	if [ -e "$EVMTEST_SECFS"/ima/policy ]; then
		POLICY=$(mktemp -u)
		cp "$EVMTEST_SECFS"/ima/policy "$POLICY"
		if grep -q "MODULE_CHECK" "$POLICY"; then
			rm "$POLICY"
			fail "$already_run"
		fi
		rm "$POLICY"
	fi
}

unload_module () {
	v_out "Unloading test module if loaded..."
	rmmod basic_mod &>> /dev/null
}



check_boot_opts () {
	if ! printf '%s' "$EVMTEST_BOOT_OPTS" | grep -E -q "$SIG_ENFORCE_CMD";
		then
		v_out "Run with kernel command: $SIG_ENFORCE_CMD"
		fail "Booted with options: $EVMTEST_BOOT_OPTS"
	else
		v_out "Booted with correct configuration..."
	fi
}

# This test may have been run before - remove the security attribute so we can
# test again
remove_xattr_appended_sig () {
	v_out "Removing security attribute and appended signature if present"
	setfattr -x security.ima "$ROOT"/files/basic_mod.ko &>> /dev/null
	strip --strip-debug "$ROOT"/files/basic_mod.ko
}

check_hash_algo () {
	# First attempt to find hash algo
	hash_alg=$(grep CONFIG_MODULE_SIG_HASH "$BUILD_DIR"/.config|awk -F "=" \
		'{print $2}'| tr -d "\"")
	# Need to read the config more to determine how to sign module...
	if [ -z "$hash_alg" ]; then
		v_out "Could not determine hash algorithm used on module"\
			"signing. Checking for other Kconfig variables..."
		hash_opts=$(grep CONFIG_MODULE_SIG "$BUILD_DIR"/.config)

		# All possible hashes from:
		# https://www.kernel.org/doc/html/v4.17/admin-guide/
		# module-signing.html
		case $hash_opts in
		*"CONFIG_MODULE_SIG_SHA1=y"*)
			hash_alg="sha1"
			;;
		*"CONFIG_MODULE_SIG_SHA224"*)
			hash_alg="sha224"
			;;
		*"CONFIG_MODULE_SIG_SHA256"*)
			hash_alg="sha256"
			;;
		*"CONFIG_MODULE_SIG_SHA384"*)
			hash_alg="sha384"
			;;
		*"CONFIG_MODULE_SIG_SHA512"*)
			hash_alg="sha512"
			;;
		*)
			fail "Could not determine hash"
			;;
		esac
	fi

	v_out "Found hash algo: $hash_alg"
}

check_signing_key () {
	v_out "Looking for signing key..."
	if [ ! -e "$BUILD_DIR"/certs/signing_key.pem ]; then
		v_out "signing_key.pem not in certs/ finding via Kconfig";
		key_location=$(grep MODULE_SIG_KEY "$BUILD_DIR"/.config)
		if [ -z "$key_location" ]; then
			fail "Could not determine key location"
		fi
		# Parse from .config
		key_location=${key_location/CONFIG_MODULE_SIG_KEY=/}
		# Drop quotes
		key_location=${key_location//\"}
		# Drop .pem
		key_location=${key_location/.pem}
		sig_key="$key_location"

	else
		sig_key="$BUILD_DIR"/certs/signing_key
	fi

	v_out "Found key: $sig_key"
}

sign_appended_signature () {
	v_out "Signing module [appended signature]..."

	if ! "$BUILD_DIR"/scripts/sign-file "$hash_alg" "$sig_key".pem \
		"$sig_key".x509 "$ROOT"/files/basic_mod.ko; then
		fail "Signing failed - please ensure sign-file is in scripts/"
	fi
}

check_appended_signature_init_mod () {
	v_out "Attempting to load signed (appended) module with INIT_MODULE"\
		" syscall [should pass]"
	if ! "$mod_load" -p "$ROOT"/files/basic_mod.ko -o &>> /dev/null;
		then
		fail "Failed to load using init_module - check key"
	fi

	v_out "Module loaded - unloading"
	rmmod basic_mod &>> /dev/null
}

check_appended_signature_finit_mod () {
	v_out "Attempting to load signed (appended) module with FINIT_MODULE"\
		" syscall [should pass]"
	if ! "$mod_load" -p "$ROOT"/files/basic_mod.ko -n &>> /dev/null;
		then
		fail "Failed to load module"
	fi

	v_out "Module loaded - unloading"
	rmmod basic_mod &>> /dev/null
}

update_policy () {
	if ! evmctl ima_sign -f "$POLICY_PATH" -k "$IMA_KEY"; then
		fail "Failed to sign policy - check key"
	fi

	v_out "Signing and loading policy to prevent loading unsigned kernel"\
		" modules..."
	if ! "$POLICY_LOAD" kernel_module_policy &>> /dev/null; then
		fail "Could not write policy - is the supplied key correct?"
	fi
}

check_appended_signature_init_mod_IMA () {
	v_out "Attempting to load signed (appended) module with FINIT_MODULE "\
		"syscall [should fail]"
	if "$mod_load" -p "$ROOT"/files/basic_mod.ko -n &>> /dev/null;
		then
		rmmod_basic_mod &>> /dev/null
		fail "FINIT_MODULE loaded module without xattr. Unloading"
	fi
	v_out "Prevented module without file attribute from loading"
}

sign_xattr () {
	v_out "Signing file [extended file attribute]..."
	if ! evmctl ima_sign -k "$IMA_KEY" -f "$ROOT"/files/basic_mod.ko; then
		fail "Error signing module - check keys"
	fi
}

check_xattr_finit_mod () {
	v_out "Attempting to load module with FINIT_MODULE syscall"\
	" [should pass]"
	"$mod_load" -p "$ROOT"/files/basic_mod.ko -n &>> /dev/null
}

check_unknown_key () {
	v_out "Signing with unknown key..."
	evmctl ima_sign -f "$ROOT"/files/basic_mod.ko &>> /dev/null
	if "$mod_load" -p "$ROOT"/files/basic_mod.ko -n &>> /dev/null;
		then
		fail "Allowed module to load with wrong signature"
	fi

	v_out "Prevented loading module signed by unknown key using"\
		" FINIT_MODULE syscall"

	if "$mod_load" -p "$ROOT"/files/basic_mod.ko -o &>> /dev/null;
		then
		fail "Allowed module to load with wrong signature"
	fi

	v_out "Prevented loading module signed by unknown key using"\
		" INIT_MODULE syscall"
}

mod_load="$ROOT"/files/simple_modload
SIG_ENFORCE_CMD="module.sig_enforce=1"
POLICY_LOAD="$ROOT"/files/load_policy.sh
POLICY_PATH="$ROOT"/files/policies/kernel_module_policy

EVMTEST_require_root
echo "[*] Starting test: $TEST"
parse_args "$@"
set_build_tree_location
check_key
check_policy
unload_module
check_boot_opts
remove_xattr_appended_sig
check_hash_algo
check_signing_key
sign_appended_signature
check_appended_signature_init_mod
check_appended_signature_finit_mod
update_policy
check_appended_signature_init_mod_IMA
sign_xattr
check_xattr_finit_mod
remove_xattr_appended_sig
passed
