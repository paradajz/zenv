#!/bin/bash

# Patch the Git repositories under $ZEPHYR_WS directory.
# A patch lookup is performed in any directory matching the zephyr/patch
# hierarchy.

patch_dirs=()

readarray -d '' patch_dirs < <(find "$ZEPHYR_WS" -type d -path "*/zephyr/patch" -print0)

for patch_dir in "${patch_dirs[@]}"
do
    echo "Searching for patches in $patch_dir"

    readarray -d '' patches < <(find "$patch_dir" -name "*.patch" -print0)

    for patch in "${patches[@]}"
    do
        patch_path=$(dirname "$patch")
        patch_basename=$(basename "$patch")
        apply_path=$ZEPHYR_WS/"${patch_path#"$patch_dir"/}"

        cd "$apply_path" || exit 1

        git config user.name "patch.sh"
        git config user.email "patch.sh@zenv.github.com"

        if git apply --check "$patch" 2>/dev/null
        then
            echo "Applying patch $patch"
            git reset --hard > /dev/null 2>&1
            git apply "$patch"
            git add .
            git commit -m "$patch_basename"
        else
            echo "Patch $patch already applied or conflicts exist in $apply_path"
        fi
    done
done
