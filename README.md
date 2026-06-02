# Testing Compat Linux: syscall testing

This project is a part of the **Google Summer of Code 2026**.

This program is meant to provide an easy and reliable way to run the LTP (Linux Test Project) syscalls tests on NetBSD, aiming to help find and solve issues with the syscall emulation.

## How it works

This script automates the download, compilation and execution of [Linux Test Project](https://github.com/linux-test-project/ltp) syscalls tests in NetBSD environment, logging the outputs.

## Requirements

To be able to use this script, the following packages should be installed:
* curl
* gmake
* pkgconf
* suse_gcc12-15.5

The module **compat_linux** should also be enabled

## How to use

1. Make sure you have the required packages installed:
    ```
    pkgin install curl gmake pkgconf # suse_gcc12-15.5
    ```
    **Note:** The latest version suse_gcc12-15.5, available in pkgin, does not include a patch needed for the compilation. To prevent errors, manually update the CVS:
    ```
    cd /usr/pkgsrc/emulators/suse15_gcc12/
    cvs update -dA
    make install
    ```  

1. Enable compat_linux module:
    ```
    modload compat_linux
    ``` 
1. Download the script and add permissions:
    ``` 
    git clone https://github.com/henriquebritoM/compat_tester
    chmod u+x compat_tester.sh 
    ```
1. Execute the script
    ```
    ./compat_tester.sh 
    ``` 

#### Options:

A number of options may be passed to the script, following the scheme: `./compat_tester.sh [OPTION]...`

`--update`: Updates the ltp version to the latest release \
`--force-reinstall`: Makes a clean ltp reinstall \
`--syscall [NAME]`: Acts only in the passed syscall. Works both in compiling and testing \
`--clean`: Clear the compiled binaries

## Where are logs stored

The output of the tests will be shown in the terminal at runtime, additionally they are stored in the `syscall_logs/` dir. 
Each entry in `syscall_logs` represents a syscall (following the same grouping/pattern used by the LTP)
