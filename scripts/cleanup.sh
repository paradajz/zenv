#!/bin/bash

# Used when starting the container via VS Code.
# The script will remove the .west-updated indicator so that the initial build
# sets everything up correctly. Otherwise, inconsistent state can occur, for
# example, the `.west-updated` indicator might exist, but after the container
# has been closed and reopened, `west` will not be updated, which can result in
# build failures.

remove()
{
    file=$1

    if [[ -f $file ]]
    then
        rm -rf "$file"
    fi
}

remove "$ZEPHYR_PROJECT"/.west-updated
