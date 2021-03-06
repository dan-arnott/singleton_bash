#!/usr/bin/env bash
# ######################################################################################################################
#
#   Copyright 2018 Dan Arnott <>
#
#   Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
#   following conditions are met:
#
#   1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
#      disclaimer.
#
#   2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
#      following disclaimer in the documentation and/or other materials provided with the distribution.
#
#   3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote
#      products derived from this software without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
#   INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#   DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#   SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#   WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
#   USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# ######################################################################################################################


# Determine absolute path of this script
declare SELF=`readlink -f "${BASH_SOURCE[0]}"`

# Set base directory based on this script
if [[ -z ${DIR_BASE} ]] ; then
  declare DIR_BASE=$(cd ` dirname "${SELF}" ` && pwd)
fi

# Set Variable Directory so value of -v switch can be set
if [[ -z ${DIR_VARS} ]] ; then
  declare DIR_VARS="${DIR_BASE}/vars"
fi

declare DEFAULT_VARS='singleton.bash'

declare GLOBAL_VARS

declare -l TASK='help'

declare -i QUIET=1

declare -i HELP=1


##  Provide help with syntax
#
function syntax_help {
  local \
    file="$( echo ${SELF} | rev | cut -d'/' -f1 | rev )"

  cat << SYNTAX

  useage:  ${file} -v file -t task -i template [-e expressions -o output -d char -k -q]
           ${file} -h

  OPTIONS:
     -v     Path to global variables
     -t     Task to perform
    [-h]    Help with syntax
    [-q]    Quiet messages and warnings

SYNTAX
}

##  Provide help with syntax and available targets
#
function task_help {
  syntax_help
  cat << HELP
  ==============================================================================
  | TARGET            | DEFINITION                                             |
  ==============================================================================
    help:               print list of available targets
  ==============================================================================

HELP
}

##  Determine which tasks to run
#
#   @param $1 string  name of target task
#
function tasks {
  local                   \
    t="${1:-'help'}"      #  default task is "help".

  case "${t}" in
  #==============================================================================#
  #==============================================================================#
    "syntax"                ) syntax_help                                      ;;
    "help"                  ) task_help                                        ;;
     *                      ) task_help                                        ;;
  #==============================================================================#
  esac
}

##  Initialize and test for required variables
#
function _init_ {
  local tmp

  # GLOBAL_VARS must be set
  if [[ -z "${GLOBAL_VARS}" ]] ; then
    prompt_for_vars_file
  fi

  load_vars_files "${GLOBAL_VARS}"

  # TASK must be set and load vars file successful
  if [[ -n "${TASK}" && $? -eq 0 ]] ; then
    tasks "${TASK}"
  else
    warning "a task was not specified"
  fi
}

##  Echo SELF filename without file extension
#
function get_filename {
  local             \
    file="$( echo ${SELF} | rev | cut -d'/' -f1 | rev )"
  echo ${file%%.*}
}

##  Prompt for GLOBAL_VARS if it hasn't been set
#
#   Attempts to suggest either the value of EXAMPLE_VARS
#   or the name of the SELF file (filename minus the extension).
#
function prompt_for_vars_file {
  local \
    filename='' \
    code=0

  printf '\n'
  warning 'missing global variables file'

  if [[ -z "${DEFAULT_VARS}" ]] ; then
    filename="${DIR_VARS}/$(get_filename)"
  else
    filename="${DIR_VARS}/${DEFAULT_VARS}"
  fi

  # Prompt for using temporary vars file
  if [[ -f "${filename}" ]] ; then
    while :; do
      echo ''
      read -p " Use the '${filename}' file: (y|n) " yn
      case $yn in
        [Yy]*) GLOBAL_VARS="${filename}"
               load_vars_files "${filename}"
               break ;;
        [Nn]*) syntax_help
               warning "A global variables file is required"
               unset TASK
               QUIET=0
               code=1
               break ;;
            *) echo "Please answer 'yes' or 'no': " ;;
      esac
    done

  # File must exist. There is no need to prompt
  # if it doesn't point to an actual file.
  else
    warning 'exiting. global vars file is required'
    syntax_help
    unset TASK
    QUIET=0
    code=1
  fi

  return ${code}
}

##  Parse a CSV string
#
#   @param  $1  csv string
#
function parse_csv {
  local csv="${1}"

  if [[ -n ${csv} ]] ; then
    echo "${csv//,/ }"
  fi
}

##  Checks the supplied global variable file before attempting to load it.
#
#   - Sends to prompt if a global variables file isn't set.
#   - Attempts to parse CSV if the global variable is not a file.
#
#   $1  string  file|path|string csv of filenames in the variables directory
#
function load_vars_files {
  local \
    globals=${1} \
    dir="${DIR_VARS}" \
    code=1

  # parse globals that are supplied as csv
  if [[ -n ${globals} && ! -f "${globals}" ]] ; then
    globals=$(parse_csv ${globals})
  fi

  for file in ${globals[@]} ; do
    path="${dir}/${file}"

    if [[ -f "${path}" ]] ; then
      source "${path}"
      typeset -i code=0
    elif [[ -f "${file}" ]] ; then
      source "${file}"
      typeset -i code=0
    fi
  done

  if [[ ${code} -gt 0 ]] ; then
    warning "missing variables file: '${globals}'"
    TASK='syntax'
  fi

  return ${code}	#	Only sends 0 if a file has been found and sourced.
}

##  Generate message for STOUT
#
#   @param $1  string  message to be formatted
#
msg() {
  local -l msgstring="${1}"
  local quiet=${QUIET}

  if [[ ${quiet} -ne 0 ]] ; then
    printf " \u2714 %s\n" "${msgstring}"
  fi
}

##  Generate message for STOUT
#
#   @param $1  string  warning message to be formatted
#
warning() {
  local -l msgstring="${1}"
  local quiet=${QUIET}

  if [[ ${quiet} -ne 0 ]] ; then
    printf " \u2718 %s\n" "${msgstring}"
  fi
}

##  Debug private functions
#
debug() {
  echo "w/o default:          '`generate_sed_expression 'BLUE'`'"
  echo "w default only:       '`generate_sed_expression 'BLUE=GREEN'`'"
  echo "w/o default w value:  '`generate_sed_expression 'KEEP'`'"
  echo "w default w value:    '`generate_sed_expression 'KEEP=FALSE'`'"

  echo "sed expression:       '`format_sed_expression 'blue' 'green' '/'`'"
  echo "tokens in template:   '`find_tokens "${TEMPLATE[@]}"`'"
  update_expressions_list "${TEMPLATE}"
  echo "commands generated:   '${#COMMANDS[@]}'"
}

##  Clean up GLOBAL VARS
#
#   It is suggested that this script is launched in a sub-shell when
#   launched by another script. (ie. `templat.bash -v ....` )
#
#   This ensures that global variables from one script don't overwrite
#   global vars by the same name created by another.
#
cleanup() {

  if [[ ${KEEP} -eq 0 ]] ; then
    : # skip
  else
    msg 'deleting expressions file'
    rm -f "${SEDSCRIPT}"
  fi

  msg "cleaning up global variables ${GLOBAL_VARS}"
  echo ''
  unset HELP
  unset QUIET
  unset GLOBAL_VARS
  unset DEFAULT_VARS
  unset TASK
  #-----------------
}

##  Process CLI options
#
#   @link  http://wiki.bash-hackers.org/howto/getopts_tutorial
#
OPTIND=1
while getopts "hkqv:t:e:o:i:d:" OPTION ; do
  case ${OPTION} in
    'h' ) HELP=0 ;;
    'q' ) QUIET=0 ;;
    'v' ) GLOBAL_VARS=$OPTARG ;;
    't' ) TASK=$OPTARG ;;
  esac
done

if [[ 'help' == ${1} || ${HELP} -eq 0 ]] ; then
  QUIET=0 && syntax_help
elif [[ 'debug' == ${1} || 'debug' == ${TASK} ]] ; then
  QUIET=0 && debug
else
  _init_
fi

cleanup
