#!/bin/bash

### Usage:
### ./example.sh --main hello --msg "2021"

readonly _DIR=$( cd -P "$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )" && pwd )
readonly BCV_DIR="${_DIR}" # Specify the path to BCV.


### Imports.
### --------

. ${BCV_DIR}/BCV/Main.sh # Must import Main.sh of BCV


### Fields.
### -------

f_msg="World" # a key-value pair
f_quiet=0 # an option


### Functions.
### ----------

function hello() {
        ### If option `quiet` is not set, then print the message.

        if ! _bool_ $f_quiet; then
                printf "Hello, ${f_msg}!\n"
        fi
}


### Entry.
### ------

main "$@" # Must include this
