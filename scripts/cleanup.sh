#!/bin/bash

# Used when starting the container via VSCode.
# The script will remove the .west-updated indicator so that the initial build
# sets everything up correctly. Otherwise, inconsistent state can occur, for
# example, .west-updated indicator might exist, but since the container has been
# closed, upon opening the container, west will not be updated resulting in possible
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
