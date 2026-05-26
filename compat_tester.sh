#!/bin/sh
#
#	compile and run LTP syscall testes on NetBSD, using Compat Linux
#
#	Usage: 
# 	todo
#
# 	Requirements:
# 	- autoconf
# 	- automake
# 	- git 
# 	- gmake
# 	- m4
# 	- pkgconf
# 	- suse_gcc12-15.5
# 	- module compat_linux enabled

# Directory where this script is located. Used as root for other paths.
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Directory where the ltp tests will be cloned
LTP_DIR="$BASE_DIR/ltp"

# Base directory for the syscalls subdirectory inside ltp
SYSCALL_DIR="${LTP_DIR}/testcases/kernel/syscalls"

# Optional: Used to specify one syscalls subdirectory inside SYSCALL_DIR
SYSCALL_COMPLEMENT=""

# Directory where compiled tests will be placed
BINARIES_DIR="${BASE_DIR}/bin"

# What compiler to use. Default searches for suse_gcc12-15.5
CC="/emul/linux/usr/bin/gcc-12"

# If the script should recompile the tests
FORCE_COMPILE="false"

compile_tests() {
	# todo
	return
}

clean() {
	rm -rf "${BINARIES_DIR:?}/*"
}

