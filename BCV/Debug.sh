#!/bin/bash

function print_args() {
        ### DEBUGGING.
        ### Print out all arguments parsed.

        local is_first=1
        printf "_r_kvargs: "
        for k in "${!_r_kvargs[@]}"; do
                if _bool_ $is_first; then
                        is_first=0
                else
                        printf " "
                fi
                printf "${k}=${_r_kvargs[$k]}"
        done
        printf "\n"

        printf "_r_optargs: ${_r_optargs[*]}\n"
}
