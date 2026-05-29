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
# 	- gmake
# 	- m4
# 	- pkgconf
# 	- suse_gcc12-15.5
# 	- curl
# 	- module compat_linux enabled

set -e

# Directory where this script is located. Used as root for other paths.
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Directory where the ltp tests will be cloned
LTP_DIR="${BASE_DIR}/ltp"

# Base directory for the syscalls subdirectory inside ltp
SYSCALL_DIR="${LTP_DIR}/testcases/kernel/syscalls"

# Optional: Used to specify one syscalls subdirectory inside SYSCALL_DIR
SYSCALL_COMPLEMENT=""

# Directory where compiled tests will be placed
BINARIES_DIR="${BASE_DIR}/bin"

# What compiler to use. Default searches for suse_gcc12-15.5
CC="/emul/linux/usr/bin/gcc-12"

# If the script should recompile the tests
FORCE_COMPILE=0

# Release version of the tests
LTP_URL=$(curl -s https://api.github.com/repos/linux-test-project/ltp/releases/latest | \
	grep "browser_download_url.*ltp-full-.*\.tar\.xz\"" | \
	cut -d'"' -f4)

# Latest release available for LTP
LTP_RELEASE=$(echo "${LTP_URL}" | sed 's/https:.*\///; s/.tar.xz//')

LTP_VERSION_FILE="${BASE_DIR}/ltp_version"

if ! [ -e "${LTP_VERSION_FILE}" ]; then
	echo 0 > "${LTP_VERSION_FILE}"
fi

# Currently installed LTP version
LTP_CURRENT_VERSION="$(cat ltp_version)"

is_ltp_latest() {
	echo "checking if the latest version of LTP is being used"

	# Not in the latest release
	if [ "${LTP_CURRENT_VERSION}" != "${LTP_RELEASE}" ]; then
		echo "Not in the latest version"
		return 1
	fi

	echo "Already in the latest version"
	return 0
}

clear_ltp() {
	# clears some related vars
	echo 0 > "${LTP_VERSION_FILE}"
	LTP_CURRENT_VERSION=0

	rm -rf "${LTP_DIR:?}" 
}

install_ltp() {

	# LTP_DIR does not exist. Download the latest release and decompress it
	if ! [ -e "${LTP_DIR}" ]; then
		echo "Downloading the latest LTP release"

		mkdir "${LTP_DIR}"
		echo "${LTP_RELEASE}" > "ltp_version"
		curl -OLs "${LTP_URL}"
		tar -xf "${LTP_RELEASE}.tar.xz" -C "${LTP_DIR}" --strip-components=1
		rm "${LTP_RELEASE}.tar.xz" # no reason to keep the tar
	fi
}

force_ltp_reinstall() {
	clear_ltp
	install_ltp
}

update_ltp() {

	if ! is_ltp_latest; then
		force_ltp_reinstall	
	fi
}

compile_tests() {
	cd "${LTP_DIR}"
	
	./configure CC="${CC}" --prefix="${BINARIES_DIR}"
	make CC="${CC}"
	make install CC="${CC}"

	cd "${BASE_DIR}"
	return
}

clean() {
	clear_ltp_dir
	rm -rf "${BINARIES_DIR:?}/*"
}

update_ltp
compile_tests
