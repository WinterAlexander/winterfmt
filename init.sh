#!/bin/bash


WINTERFMT_FILE="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)/.clang-format"
export WINTERFMT_FILE="$WINTERFMT_FILE"

function winterfmt() {(
	if [ "$#" -eq 0 ]; then
		winterfmt -i $(ls **/*.java)
		return
	fi

	cmdopts=$(grep -oE "\-([A-Za-z0-9]|-|=)+" <<< $@)

	set -e
	cmd="clang-format --style=file:$WINTERFMT_FILE $@ 2>&1"
	output=$(script -q -c "$cmd" /dev/null)
	if [[ $cmdopts =~ "-i" ]]; then
		perl -g -i -pe 's/(catch\s*\(([A-Za-z0-9]|\|\.|\s)+ignored\)(\s*\n*)*)\{\s+\}/\1\{\}/igs' "$@"
	elif [[ $cmdopts =~ "-n" ]] || [[ $cmdopts =~ "--dry-run" ]]; then
		unwanted=$(grep catch -C 1 <<< "$output")
		output=$(grep -vF "$unwanted" <<< "$output")
	fi
	output=$(sed 's/^\s*\|\s*$//g' <<< "$output")
	colorless=$(sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' <<< "$output")
	if [[ $colorless =~ [^[:space:]] ]]; then
		echo "$output"
		return 1
	fi
)}

function __broken_winterfmt() {(
	if [ "$#" -eq 0 ]; then
		__broken_winterfmt -i $(ls **/*.java)
		return
	fi

	cmdopts="$(echo "$@" | grep -oE "\-([A-Za-z0-9]|-|=)+")"
	if [ -n "$cmdopts" ]; then
		cmdopts="$cmdopts"
	fi

	set -e
	for file in "$@"; do
		if [[ "$file" =~ ^"-" ]]; then
			continue
		fi

		if [ ! -f "$file" ]; then
			continue
		fi

		lines=$(sed -nr '/catch\(([A-Za-z0-9]|\s|\.|\|)* ignored\)\s*\{\s*\}/=' $file)
		if ! [[ -n $lines ]]; then
			cmd="clang-format --style=file:$WINTERFMT_FILE $cmdopts $file"
			eval $cmd
			continue
		fi

		lines=$(echo "$lines" | tr '\n' ' ')
		ranges=$(awk -v max=$(wc -l < "$file") '
		BEGIN {
			split("'"$lines"'", lines)

			for(i in lines)
				skip[lines[i]] = 1

			start = 1
			for(i = 1; i <= max; i++) {
				if(skip[i]) {
					if(start < i)
						printf "--lines=%d:%d ", start, i - 1
					start = i + 1
				}
			}

			if(start <= max)
				printf "--lines=%d:%d", start, max
		}')
		cmd="clang-format --style=file:$WINTERFMT_FILE $cmdopts $ranges $file"
		echo $cmd
		eval $cmd
	done
)}
