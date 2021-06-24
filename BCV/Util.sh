#!/bin/bash

### Syntactic sugar.
### ----------------

function _bool_() {
        ### Cast value to bool type. We use C-like rule, treating zero
        ### as false otherwise true.
        ### @val any value
        local val="$1"

        ## This might look weird but "return 0" means OK (true) in
        ## Bash.
        if [[ $val == 0 ]]; then
                return 1
        else
                return 0
        fi
}


### Type.
### -----

function is_function_set() {
        ### Return true if the given name is a function defined in the
        ### script.
        ### @name function name
        local name="$1"

        if [[ "$( type -t "$name" )" = 'function' ]]; then
                return 0
        else
                return 1
        fi
}

function is_variable_set() {
        ### Returns true if the given variable is set.
        ### @name variable name
        local name="$1"

        eval "ret=\$( test ! -z \${${name}+x} )"
        return $ret
}

function get_stacktrace() {
        ### Print stack trace from the current subroutine call.

        local stacktrace=""
        local frame=0 line sub file
        while read line sub file < <( caller "$frame" ); do
                stacktrace="${stacktrace}$( printf '        at %s(%s:%s)' "${sub}" "${file}" "${line}" )"$'\n'
                ((frame++))
        done
        printf "${stacktrace}"
}

function get_entry_script() {
        ### Get the name of script at the bottom frame.

        local frame=0
        local file prev_file _
        while read _ _ file < <( caller "$frame" ); do
                ((frame++))
                prev_file="$file"
        done
        echo "${prev_file}"
}


### Log.
### ----

function log_i() {
        ### Log at info level.
        ### @msg text of log

        local msg="$1"; shift

        log i "$msg"
}

function log_d() {
        ### Log at debugging level.
        ### @msg text of log

        local msg="$1"; shift

        log d "$msg"
}

function log_e_and_exit() {
        ### Log at error level and then exit with 1.
        ### @msg text of log

        local msg="$1"; shift

        log_e "$msg"
        exit 1
}

function log_e() {
        ### Log at error level.
        ### @msg text of log

        local msg="$1"; shift

        log e "$msg"
}

function log() {
        ### Log.
        ### @level log level, one of "info, debug, error or warning"
        ### @msg text of log

        local level="$1"; shift
        local msg="$1"; shift

        log0 "$level" "$msg" "BCV:"
}

function log0() {
        ### Log messages.
        ### @level log level, one of "info, debug, error or warning"
        ### @msg text of log
        ### @prefix prefix added to the message

        local level="$1"; shift
        local msg="$1"; shift
        local prefix="$1"; shift

        case "$level" in
        'i'|'info')
                println_err "${prefix}INFO: ${msg}"
                ;;
        'd'|'debug')
                println_err "${prefix}DEBUG: ${msg}"
                ;;
        'e'|'error')
                println_err "${prefix}ERROR: ${msg}"
                println_err "$( get_stacktrace )"
                ## TODO: is it good to exit here?
                exit 1
                ;;
        'w'|'warning')
                println_err "${prefix}WARNING: ${msg}"
                ;;
        *)
                println_err "${prefix}ERROR: Unrecognized logging level: ${level}"
                exit 1
                ;;
        esac
}


### Println.
### --------

function println() {
        ### Print message to std out with a newline.
        ### @msg
        local msg="$1"

        printf -- "${msg}\n"
}

function println_err() {
        ### Print message to std err with a newline.
        ### @msg
        local msg="$1"

        println "${msg}" 1>&2
}


### Assert.
### -------

function assert_var_set() {
        ### Assert a variable is set.
        ### @name variable name

        local name="$1"; shift
        if ! is_variable_set "$name"; then
                log e "Variable \"${name}\" is NOT set!"
        fi
}

function assert_file_exists() {
        ### Assert a file exists.
        ### @file the path of the given file

        local file="$1"; shift
        test -f "$file" || log e "File $file does NOT exist!"
}


### Time.
### -----

function curr_millis() {
        ### Return the current time in GMT in milliseconds.

        echo "$(($(date -u +%s%N)/1000000))"
}

function millis_to_human_readable_format() {
        ### Return day:hour:min:second:millisecond format (no leading
        ### zeros) for the given number of milliseconds.

        local millis="$1"; shift

        # Convert
        local milliseconds=$((${millis}%1000))
        local seconds=$((${millis}/1000%60))
        local minutes=$((${millis}/1000/60%60))
        local hours=$((${millis}/1000/60/60%24))
        local days=$((${millis}/1000/60/60/24))

        # Remove leading zeros
        local output=""
        if [[ ${days} -eq 0 ]]; then
                if [[ ${hours} -eq 0 ]]; then
                        if [[ ${minutes} -eq 0 ]]; then
                                if [[ ${seconds} -eq 0 ]]; then
                                        output="${milliseconds}ms"
                                else
                                        output="${seconds}s:${milliseconds}ms"
                                fi
                        else
                                output="${minutes}m:${seconds}s:${milliseconds}ms"
                        fi
                else
                        output="${hours}h:${minutes}m:${seconds}s:${milliseconds}ms"
                fi
        else
                output="${days}d:${hours}h:${minutes}m:${seconds}s:${milliseconds}ms"
        fi

        echo "${output}"
}


### List directories and files.
### ---------------------------

function list_dirs() {
        ### List all the directories non-recursively under the given
        ### path.
        local path="$1"; shift

        echo "$( find "${path}" -maxdepth 1 -mindepth 1 -type d | sed 's/.*\///' | sort -V )"
}

function list_dir_paths() {
        ### List all the directories non-recursively under the given
        ### path.
        local path="$1"; shift

        echo "$( find "${path}" -maxdepth 1 -mindepth 1 -type d | sort -V )"
}

function list_files() {
        ### List all the files with a name matching the given pattern
        ### under the given path.
        local path="$1"; shift
        if [[ $# -gt 0 ]]; then
                local pattern="$1"
        else
                local pattern="*"
        fi

        list_file_paths "$path" "$pattern" | xargs -I{} basename {}
}

function list_file_paths() {
        ### List the absolute paths of all the files with a name
        ### matching the given pattern under the given path.
        local path="$1"; shift
        if [[ $# -gt 0 ]]; then
                local pattern="$1"
        else
                local pattern="*"
        fi

        find "${path}" -maxdepth 1 -mindepth 1 -type f -name "${pattern}" | sort -V
}
