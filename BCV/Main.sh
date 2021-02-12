#!/bin/bash

readonly BCV_ROOT_DIR=$( cd -P "$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )" && pwd )

### Environments.
### -------------

## TODO: Treat unset variables as an error.
# set -u


### Directories.
### ------------

readonly DOT_DIR=".bcv"
readonly LOGS_DIR="${DOT_DIR}/logs"; mkdir -p ${LOGS_DIR}


### Imports.
### --------

. ${BCV_ROOT_DIR}/Util.sh # utility functions.
. ${BCV_ROOT_DIR}/Debug.sh # debugging functions.


### Parse command line arguments.
### -----------------------------

declare -A _r_kvargs=()
declare -a _r_optargs=()
declare -a _r_positional=()

_r_main="" ## function as entry

function parse_args() {
        ### Parse arguments.

        local is_pos=0
        while [[ $# -gt 0 ]]; do
                local arg="$1"

                ## We have to use else if because case does not
                ## support regexp.
                if _bool_ $is_pos; then
                        ## Treat as a positional argument.
                        _r_positional+=("$1")
                        shift # past argument
                elif [[ $arg == '--help' ]]; then
                        ## Print help text
                        print_help_text
                        exit 0
                elif [[ $arg == '--main' ]]; then
                        _r_main="$2"
                        shift # past key
                        shift # past value
                elif [[ $arg =~ \-\-[[:alnum:]_][[:alnum:]]* ]]; then
                        local key="${arg:2}"
                        if [[ $# -eq 1 || $2 == '--'* ]]; then
                                ## If there is no argument following
                                ## or the next one starts with --,
                                ## then the current one is actually an
                                ## option.
                                _r_optargs+=("$key")
                                shift # past key/option
                        else
                                ## Otherwise the current one is really
                                ## a key-value pair.
                                _r_kvargs["$key"]+="$2"
                                shift # past key/option
                                shift # past value
                        fi
                elif [[ $arg == '--' ]]; then
                        # treat the following arguments as positional.
                        is_pos=1
                        shift
                else
                        println_err "unrecognized argument: $arg"
                        print_hint_text
                        exit 1
                fi
        done

        # set -- "${_r_positional[@]}"
}

function set_fields() {
        ### Set corresponding fields based on arguments parsed.

        ## Set each key-value field.
        for k in ${!_r_kvargs[@]}; do
                local field_name="f_$k"
                if is_variable_set "${field_name}"; then
                        ## If the field is defined by users, we update
                        ## its value.
                        eval "${field_name}=\"${_r_kvargs[$k]}\""
                else
                        ## If the field is NOT defined, we throw an
                        ## error.
                        log e "Field ${k} is NOT defined!"
                fi
        done

        ## TODO: maybe we need to reconsider the logic of options. For
        ## now we require users to define an option field as 0.
        ## Set each value field.
        for opt in ${_r_optargs[@]}; do
                local field_name="f_$opt"
                if is_variable_set "${field_name}"; then
                        ## If the field is defined by users, we set it
                        ## to true.
                        eval "f_${opt}=1"
                else
                        ## If the field is NOT defined, we throw an
                        ## error.
                        log e "Field ${opt} is NOT defined!"
                fi
        done
}

function print_help_text() {
        ### Print predefined help text to std out.

        println "Usage: SCRIPT --main FUNCTION --FIELD1 VALUE1 --FIELD2 VALUE2"
        println "Framework for running your bash scripts."
        println "Example: ./example.sh --main hello --msg 2021"
        println
        println "Options:"
        println "  --help display this help text and exit"
}

function print_hint_text() {
        ### Print predefined error text to std out.

        println "Usage: SCRIPT --main FUNCTION --FIELD1 VALUE1 --FIELD2 VALUE2"
        
        println "Try \'$( get_entry_script ) --help\' for more information."
}


### Main.
### -----

function main() {
        ### Main.

        parse_args "$@"

        ## DEBUG
        # printf "_r_main: ${_r_main}\n"
        # print_args

        ## Check if main is set
        if [[ -z ${_r_main} ]]; then
                println_err "main function is NOT specified!"
                exit 1
        fi

        ## Check if main is a valid function
        if ! is_function_set "$_r_main"; then
                println_err "function $_r_main is NOT defined!"
                exit 1
        fi

        set_fields

        ## Execute the function
        ## https://wiki.bash-hackers.org/howto/redirection_tutorial
        ## {
        ##         {
        ##                 cmd1 3>&- |
        ##                         cmd2 2>&3 3>&-
        ##         } 2>&1 >&4 4>&- |
        ##                 cmd3 3>&- 4>&-
        ## } 3>&2 4>&1
        ##
        ##                                                            cmd2
        ##
        ##                                            ---       +-------------+
        ##                                        -->( 0 ) ---->| 1st pipe    |
        ##                                       /    ---       +-------------+
        ##                                      /
        ##                                     /      ---       +-------------+
        ##          cmd 1                     /      ( 1 ) ---->| /dev/pts/5  |
        ##                                   /        ---       +-------------+
        ##                                  /
        ##  ---       +-------------+      /          ---       +-------------+
        ## ( 0 ) ---->| /dev/pts/5  |     /          ( 2 ) ---->| /dev/pts/5  |
        ##  ---       +-------------+    /            ---       +-------------+
        ##                              /
        ##  ---       +-------------+  /                       cmd3
        ## ( 1 ) ---->| 1st pipe    | /
        ##  ---       +-------------+                 ---       +-------------+
        ##                              ------------>( 0 ) ---->| 2nd pipe    |
        ##  ---       +-------------+ /               ---       +-------------+
        ## ( 2 ) ---->| 2nd pipe    |/
        ##  ---       +-------------+                 ---       +-------------+
        ##                                           ( 1 ) ---->| /dev/pts/5  |
        ##                                            ---       +-------------+
        ##
        ##                                            ---       +-------------+
        ##                                           ( 2 ) ---->| /dev/pts/5  |
        ##                                            ---       +-------------+

        local log_file="${LOGS_DIR}/$( date --iso-8601=ns ).log"
        touch ${log_file}
        log d "${log_file}"
        {
                {
                        $_r_main "${_r_positional[@]}" 3>&- >>"${log_file}"
                } 2>&1 >&4 4>&- |
                        tee -a "${log_file}" 3>&- 4>&-
        } 3>&2 4>&1
        return "${PIPESTATUS[0]}"
}
