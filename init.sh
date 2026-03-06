#!/bin/bash


# locale .clang-format (same directory as this script)
WINTERFMT_FILE="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)/.clang-format"
export WINTERFMT_FILE="$WINTERFMT_FILE"

function winterfmt() {(
	echo "#1"
	# no args -> format whole project (zshell only)
	if [ "$#" -eq 0 ]; then
		echo "#2"
		files=`find . -name *.java -exec echo {} \; | tr '\n' ' '`
		if ! [[ $files =~ [^[:space:]] ]]; then
			echo "No .java file found in subdirectories"
			return 2
		fi

		echo "#3"
		winterfmt -i "$files"
		return $?
	fi

	echo "#4"
	if [[ "$@" == "check" ]]; then
		echo "#5"
		files=`find . -name *.java -exec echo {} \; | tr '\n' ' '`
		if ! [[ $files =~ [^[:space:]] ]]; then
			echo "No .java file found in subdirectories"
			return 2
		fi

		echo "#6"
		winterfmt -n "$files"
		return $?
	fi

	echo "#7"
	# extract options (words starting with -)
	cmdopts=$(grep -oE "\-([A-Za-z0-9]|-|=)+" <<< $@)

	# call clang-format with the same arguments but pass .clang-format file. Redirect stderr to
	# stdout in order to manipulate it later
	cmd="clang-format --style=file:$WINTERFMT_FILE $@ 2>&1"


	echo "#8"
	set +e
	# call script in order to capture the output while preserving colors. -e to get the output code
	output=$(clang-format --style="file:$WINTERFMT_FILE" "$@" 2>&1)
	#output=$(script -q -e -c "$cmd" /dev/null)
	code=$?

	echo "#9"
	if ! [ "$code" -eq 0 ]; then
		# error returned by clang-format
		echo "$output"
		return $code
	fi

	echo "#10"
	# from here any error is a grep mistake
	set -e
	if [[ $cmdopts =~ "-i" ]]; then
		# do the catch{} replacement
		perl -g -i -pe 's/(catch\s*\(([A-Za-z0-9]|\|\.|\s)+ignored\)(\s*\n*)*)\{\s+\}/\1\{\}/igs' "$@"
	elif [[ $cmdopts =~ "-n" ]] || [[ $cmdopts =~ "--dry-run" ]]; then
		# get lines with catch and then remove them TODO better macro
		unwanted=$(grep -E "catch\s*\(([A-Za-z0-9]|\|\.|\s)+ignored\)\s*\{\}" -C 1 <<< "$output")
		output=$(grep -vF "$unwanted" <<< "$output")
	fi

	echo "#11"

	# removes spaces at the beginning or end
	output=$(sed 's/^\s*\|\s*$//g' <<< "$output")
	# removes colors
	colorless=$(sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' <<< "$output")
	if [[ $colorless =~ [^[:space:]] ]]; then

		echo "#12"
		# if there is output then its an error
		echo "$output"
		return 1
	fi
	echo "#13"
	return 0
)}
