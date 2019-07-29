#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# ima-evm-utils tests bash functions
#
# Copyright (C) 2019 Vitaly Chikunov <vt@altlinux.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# Tests accounting
declare -i testspass=0 testsfail=0 testsskip=0

# Exit codes (compatible with automake)
declare -r OK=0
declare -r FAIL=1
declare -r HARDFAIL=99 # hard failure no matter testing mode
declare -r SKIP=77     # skip test

# You can set env VERBOSE=1 to see more output from evmctl
V=vvvv
V=${V:0:$VERBOSE}
V=${V:+-$V}

# Exit if env FAILEARLY is defined.
# Used in expect_{pass,fail}.
exit_early() {
  if [ $FAILEARLY ]; then
    exit $1
  fi
}

# Require particular executables to be present
_require() {
  ret=
  for i; do
    if ! type $i; then
      echo "$i is required for test"
      ret=1
    fi
  done
  [ $ret ] && exit $HARDFAIL
}

# Only allow color output on tty
if tty -s; then
     RED=$'\e[1;31m'
   GREEN=$'\e[1;32m'
  YELLOW=$'\e[1;33m'
    BLUE=$'\e[1;34m'
    CYAN=$'\e[1;36m'
    NORM=$'\e[m'
fi

# Test mode determined by TFAIL variable:
#   undefined: to success testing
#   defined: failure testing
TFAIL=
TMODE=+ # mode character to prepend running command in log
declare -i TNESTED=0 # just for sanity checking

# Run positive test (one that should pass) and account its result
expect_pass() {
  local ret

  if [ $TNESTED -gt 0 ]; then
    echo $RED"expect_pass should not be run nested"$NORM
    testsfail+=1
    exit $HARDFAIL
  fi
  TFAIL=
  TMODE=+
  TNESTED+=1
  [[ "$VERBOSE" -gt 1 ]] && echo "____ START positive test: $@"
  "$@"
  ret=$?
  [[ "$VERBOSE" -gt 1 ]] && echo "^^^^ STOP ($ret) positive test: $@"
  TNESTED+=-1
  case $ret in
    0)  testspass+=1 ;;
    77) testsskip+=1 ;;
    99) testsfail+=1; exit_early 1 ;;
    *)  testsfail+=1; exit_early 2 ;;
  esac
  return $ret
}

# Eval negative test (one that should fail) and account its result
expect_fail() {
  local ret

  if [ $TNESTED -gt 0 ]; then
    echo $RED"expect_fail should not be run nested"$NORM
    testsfail+=1
    exit $HARDFAIL
  fi

  TFAIL=yes
  TMODE=-
  TNESTED+=1
  [[ "$VERBOSE" -gt 1 ]] && echo "____ START negative test: $@"
  "$@"
  ret=$?
  [[ "$VERBOSE" -gt 1 ]] && echo "^^^^ STOP ($ret) negative test: $@"
  TNESTED+=-1
  case $ret in
    0)  testsfail+=1; exit_early 3 ;;
    77) testsskip+=1 ;;
    99) testsfail+=1; exit_early 4 ;;
    *)  testspass+=1 ;;
  esac
  TFAIL= # Restore defaults for tests run without wrappers
  TMODE=+
  return $ret
}

# return true if current test is positive
_is_expect_pass() {
  [ ! $TFAIL ]
}

# return true if current test is negative
_is_expect_fail() {
  [ $TFAIL ]
}

# Show blank line and color following text to red
# if it's real error (ie we are in expect_pass mode).
red_if_failure() {
  if _is_expect_pass; then
    echo $@ $RED
    COLOR_RESTORE=1
  fi
}

# For hard errors
red_always() {
  echo $@ $RED
  COLOR_RESTORE=1
}

color_restore() {
  [ $COLOR_RESTORE ] && echo $@ $NORM
  COLOR_RESTORE=
}

ADD_DEL=
ADD_TEXT_FOR=
# _evmctl_run should be run as `_evmctl_run ... || return'
_evmctl_run() {
  local op=$1 out=$1-$$.out
  local text_for=${FOR:+for $ADD_TEXT_FOR}
  # Additional parameters:
  # ADD_DEL: additional files to rm on failure
  # ADD_TEXT_FOR: append to text as 'for $ADD_TEXT_FOR'

  cmd="evmctl $V ${ENGINE:+--engine $ENGINE} $@"
  echo $YELLOW$TMODE $cmd$NORM
  $cmd >$out 2>&1
  ret=$?

  # Shell special and signal exit codes (except 255)
  if [ $ret -ge 126 -a $ret -lt 255 ]; then
    red_always
    echo "evmctl $op failed hard with ($ret) $text_for"
    sed 's/^/  /' $out
    color_restore
    rm $out $ADD_DEL
    ADD_DEL=
    ADD_TEXT_FOR=
    return $HARDFAIL
  elif [ $ret -gt 0 ]; then
    red_if_failure
    echo "evmctl $op failed" ${TFAIL:+properly} "with ($ret) $text_for"
    # Show evmctl output only in verbose mode or if real failure.
    if _is_expect_pass || [ "$VERBOSE" ]; then
      sed 's/^/  /' $out
    fi
    color_restore
    rm $out $ADD_DEL
    ADD_DEL=
    ADD_TEXT_FOR=
    return $FAIL
  elif _is_expect_fail; then
    red_always
    echo "evmctl $op wrongly succeeded $text_for"
    sed 's/^/  /' $out
    color_restore
  else
    [ "$VERBOSE" ] && sed 's/^/  /' $out
  fi
  rm $out
  ADD_DEL=
  ADD_TEXT_FOR=
  return $OK
}

# Extract xattr $attr from $file into $out file skipping $pref'ix
_extract_xattr() {
  local file=$1 attr=$2 out=$3 pref=$4

  getfattr -n $attr -e hex $file \
    | grep "^$attr=" \
    | sed "s/^$attr=$pref//" \
    | xxd -r -p > $out
}

# Test if xattr $attr in $file matches $pref'ix
# Show error and fail otherwise.
_test_xattr() {
  local file=$1 attr=$2 pref=$3
  local test_for=${ADD_TEXT_FOR:+ for $ADD_TEXT_FOR}

  if ! getfattr -n $attr -e hex $file | egrep -qx "$attr=$pref"; then
    red_if_failure
    echo "Did not find expected hash$text_for:"
    echo "    $attr=$pref"
    echo ""
    echo "Actual output below:"
    getfattr -n $attr -e hex $file | sed 's/^/    /'
    color_restore
    rm $file
    ADD_TEXT_FOR=
    return $FAIL
  fi
  ADD_TEXT_FOR=
}

# Try to enable gost-engine if needed.
_enable_gost_engine() {
  # Do not enable if it's already working (enabled by user)
  if ! openssl md_gost12_256 /dev/null >/dev/null 2>&1 \
    && openssl engine gost >/dev/null 2>&1; then
    ENGINE=gost
  fi
}

# Show test stats and exit into automake test system
# with proper exit code (same as ours).
_report_exit() {
  if [ $testsfail -gt 0 ]; then
    echo "================================="
    echo " Run with FAILEARLY=1 $0 $@"
    echo " To stop after first failure"
    echo "================================="
  fi
  [ $testspass -gt 0 ] && echo -n $GREEN || echo -n $NORM
  echo -n "PASS: $testspass"
  [ $testsskip -gt 0 ] && echo -n $YELLOW || echo -n $NORM
  echo -n " SKIP: $testsskip"
  [ $testsfail -gt 0 ] && echo -n $RED || echo -n $NORM
  echo " FAIL: $testsfail"
  echo $NORM
  if [ $testsfail -gt 0 ]; then
    exit $FAIL
  elif [ $testspass -gt 0 ]; then
    exit $OK
  else
    exit $SKIP
  fi
}
