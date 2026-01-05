#!/bin/bash
DEFAULT_SH=$(cd $(dirname $0) && pwd)
folder_to_check=${DEFAULT_SH}/JS-MODS

memu_name () {
find "$folder_to_check" -type d | while read folder; do
    if [[ "$folder" = *" "* ]]; then
        new_folder="${folder// /_}"
        mv "$folder" "$new_folder" 2>/dev/null
        if [ $? -eq 0 ]; then
			echo
		else
			memu_name
		fi
    fi
done
}

memu_name