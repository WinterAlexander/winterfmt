#!/bin/bash

# locale .clang-format (same directory as this script)
if [ -z ${ZSH_VERSION+check} ]; then
	WINTERFMT_FILE="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)/.clang-format"
else
	# avoid doing this on non zshell shells because of the ide build below
	WINTERFMT_FILE="$(cd -- "$( dirname -- "${BASH_SOURCE[0]:-${(%):-%x}}")" &> /dev/null && pwd)/.clang-format"
fi
export WINTERFMT_FILE="$WINTERFMT_FILE"

#
# Main function for formatting using the winterfmt format. Meant to be called directly from the
# shell as a bash function. When no argument, does a replace on all Java files in subdirectories
# and has a convenience option 'check' to do a check on all Java files in subdirectories instead.
# Otherwise, arguments are passed to clang-format. After formatting, this formatter will do
# transformations on all input files. After checking, this formatter will modify the check output
# and possibly return code to ensure the desired format returns no errors.
#
function winterfmt() {(
	# no args -> format whole project (zshell only)
	if [ "$#" -eq 0 ]; then
		files=`find . -name '*.java' -exec echo {} \; | tr '\n' ' '`
		if ! [[ $files =~ [^[:space:]] ]]; then
			echo "No .java file found in subdirectories"
			return 2
		fi

		winterfmt -i "$files"
		return $?
	fi

	if [[ "$@" == "check" ]]; then
		files=`find . -name '*.java' -exec echo {} \; | tr '\n' ' '`
		if ! [[ $files =~ [^[:space:]] ]]; then
			echo "No .java file found in subdirectories"
			return 2
		fi

		winterfmt -n -Werror "$files"
		return $?
	fi

	# extract options (words starting with -)
	cmdopts=$(grep -oE "\-([A-Za-z0-9]|-|=)+" <<< $@)

	set +e

	# call clang-format with the same arguments but pass .clang-format file. Redirect stderr to
	# stdout in order to manipulate it later
	if [[ $cmdopts =~ "--fno-color-diagnostics" ]]; then
		output=$(${WINTERFMT_CLANG_FORMAT:-clang-format} --style=file:$WINTERFMT_FILE $@ 2>&1)
	else
		# call script in order to capture the output while preserving colors. -e to get the output code
		cmd="${WINTERFMT_CLANG_FORMAT:-clang-format} --style=file:$WINTERFMT_FILE $@ 2>&1"
		output=$(script -q -e -c "$cmd" /dev/null)
	fi

	code=$?

	if [[ $cmdopts =~ "-n" ]] || [[ $cmdopts =~ "--dry-run" ]]; then
		# get lines with catch and then remove them
		unwanted=$(grep -E "catch\s*\(([A-Za-z0-9]|\|\.|\s)+ignored\)\s*\{\}" -C 1 <<< "$output")
		output=$(grep -vF "$unwanted" <<< "$output")

		# removes spaces at the beginning or end
		output=$(sed 's/^\s*\|\s*$//g' <<< "$output")
	fi

	if ! [ "$code" -eq 0 ]; then
		if [[ $cmdopts =~ "-n" ]] || [[ $cmdopts =~ "--dry-run" ]]; then
			# removes colors
			colorless=$(sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' <<< "$output")
			if [[ $colorless =~ [^[:space:]] ]]; then
				# if there is still output then its an error
				echo "$output"
				return $code
			fi
			# otherwise then we simulate success
			return 0
		fi
		# error returned by clang-format
		echo "$output"
		return $code
	fi

	if [[ $cmdopts =~ "-i" ]]; then
		# do the catch{} replacement
		sed -r 's/-([A-Za-z0-9]|-|=)+//g' <<< $@ | xargs perl -g -i -pe 's/(catch\s*\(([A-Za-z0-9]|\|\.|\s)+ignored\)(\s*\n*)*)\{\s+\}/\1\{\}/igs'
	fi

	if [[ -n "$output" ]]; then
		echo "$output"
	fi
	return 0
)}

#
# Builds an executable for use by an IDE. This is needed for the IntelliJ clang-format plugin which
# expects to launch an executable and not a bash function.
#
function build_winterfmt_ide() {(
	cat ${BASH_SOURCE[0]:-${(%):-%x}} > ide_runner.sh
	echo "\nexport WINTERFMT_FILE=$WINTERFMT_FILE" >> ide_runner.sh
	echo 'winterfmt $@' >> ide_runner.sh
	shc -f ide_runner.sh
)}