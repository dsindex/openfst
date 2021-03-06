#!/bin/bash

set -o nounset
set -o errexit

VERBOSE_MODE=0

function error_handler()
{
  local STATUS=${1:-1}
  [ ${VERBOSE_MODE} == 0 ] && exit ${STATUS}
  echo "Exits abnormally at line "`caller 0`
  exit ${STATUS}
}
trap "error_handler" ERR

PROGNAME=`basename ${BASH_SOURCE}`
DRY_RUN_MODE=0

function print_usage_and_exit()
{
  set +x
  local STATUS=$1
  echo "Usage: ${PROGNAME} [-v] [-v] [--dry-run] [-h] [--help]"
  echo ""
  echo " Options -"
  echo "  -v                 enables verbose mode 1"
  echo "  -v -v              enables verbose mode 2"
  echo "      --dry-run      show what would have been dumped"
  echo "  -h, --help         shows this help message"
  exit ${STATUS:-0}
}

function debug()
{
  if [ "$VERBOSE_MODE" != 0 ]; then
    echo $@
  fi
}

GETOPT=`getopt -o vh --long dry-run,help -n "${PROGNAME}" -- "$@"`
if [ $? != 0 ] ; then print_usage_and_exit 1; fi

eval set -- "${GETOPT}"

while true
do case "$1" in
     -v)            let VERBOSE_MODE+=1; shift;;
     --dry-run)     DRY_RUN_MODE=1; shift;;
     -h|--help)     print_usage_and_exit 0;;
     --)            shift; break;;
     *) echo "Internal error!"; exit 1;;
   esac
done

if (( VERBOSE_MODE > 1 )); then
  set -x
fi


# template area is ended.
# -----------------------------------------------------------------------------
if [ ${#} != 0 ]; then print_usage_and_exit 1; fi

# current dir of this script
CDIR=$(readlink -f $(dirname $(readlink -f ${BASH_SOURCE[0]})))
PDIR=$(readlink -f $(dirname $(readlink -f ${BASH_SOURCE[0]}))/..)

# -----------------------------------------------------------------------------
# functions

function make_calmness()
{
	exec 3>&2 # save 2 to 3
	exec 2> /dev/null
}

function revert_calmness()
{
	exec 2>&3 # restore 2 from previous saved 3(originally 2)
}

function close_fd()
{
	exec 3>&-
}

function jumpto
{
	label=$1
	cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
	eval "$cmd"
	exit
}


# end functions
# -----------------------------------------------------------------------------



# -----------------------------------------------------------------------------
# main 

make_calmness
if (( VERBOSE_MODE > 1 )); then
	revert_calmness
fi

function draw {
	local _fst=$1
	local _dot=$2
	local _png=$3
	local _isyms=${CDIR}/ascii.syms
	local _osyms=${CDIR}/ascii.syms

	fstdraw --isymbols=$_isyms --osymbols=$_osyms $_fst $_dot
	dot -Tpng $_dot > $_png
}

isyms=${CDIR}/ascii.syms
osyms=${CDIR}/ascii.syms

cd ${CDIR}

python make_T.py > T.txt
fstcompile --isymbols=$isyms --osymbols=$osyms T.txt T.fst
draw T.fst T.dot T.png

fstcompile --isymbols=$isyms --osymbols=$osyms abc.txt > abc.fst
fstcompose abc.fst T.fst > abc_T.fst
draw abc_T.fst abc_T.dot abc_T.png

fstcompile --isymbols=$isyms --osymbols=$osyms cba.txt > cba.fst
fstcompose abc.fst T.fst | fstcompose - cba.fst > abc_T_cba.fst
draw abc_T_cba.fst abc_T_cba.dot abc_T_cba.png

fstshortestpath abc_T_cba.fst > shortest.fst
draw shortest.fst shortest.dot shortest.png

close_fd

# end main
# -----------------------------------------------------------------------------
