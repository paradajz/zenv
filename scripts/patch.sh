#!/bin/bash

# Patch the Git repositories under $ZEPHYR_WS directory.
# A patch lookup is performed in any directory matching the zephyr/patch
# hierarchy.

patch_dirs=()
apply_paths=()
declare -A seen_patch_dirs
declare -A patch_files_by_apply_path
declare -A patch_log_limit_by_apply_path

# Search both the Zephyr workspace and the active project checkout. In
# native CI containers, the project checkout can live outside $ZEPHYR_WS.
# De-duplicate patch directories because local checkouts usually live under
# $ZEPHYR_WS/project and are reachable through both roots.
for patch_search_root in "$ZEPHYR_WS" "$ZENV_PROJECT_ROOT"
do
    if [[ ! -d "$patch_search_root" ]]
    then
        continue
    fi

    while IFS= read -r -d '' patch_dir
    do
        if [[ -n "${seen_patch_dirs[$patch_dir]:-}" ]]
        then
            continue
        fi

        patch_dirs+=("$patch_dir")
        seen_patch_dirs[$patch_dir]=1
    done < <(find "$patch_search_root" -type d -path "*/zephyr/patch" -print0)
done

for patch_dir in "${patch_dirs[@]}"
do
    readarray -d '' patches < <(find "$patch_dir" -name "*.patch" -print0 | sort -z)

    for patch in "${patches[@]}"
    do
        patch_path=$(dirname "$patch")
        apply_path=$ZEPHYR_WS/"${patch_path#"$patch_dir"/}"

        if [[ -z "${patch_log_limit_by_apply_path[$apply_path]}" ]]
        then
            apply_paths+=("$apply_path")
            patch_log_limit_by_apply_path[$apply_path]=0
        fi

        patch_files_by_apply_path[$apply_path]+="$patch"$'\n'
        patch_log_limit_by_apply_path[$apply_path]=$((patch_log_limit_by_apply_path[$apply_path] + 1))
    done
done

for apply_path in "${apply_paths[@]}"
do
    cd "$apply_path" || exit 1

    readarray -t patches <<< "${patch_files_by_apply_path[$apply_path]}"
    applied_patch_subjects=$(git log --format=%s --max-count="${patch_log_limit_by_apply_path[$apply_path]}")

    git config user.name "patch.sh"
    git config user.email "patch.sh@zenv.github.com"

    for patch in "${patches[@]}"
    do
        if [[ -z "$patch" ]]
        then
            continue
        fi

        patch_basename=$(basename "$patch")

        if grep -Fxq "$patch_basename" <<< "$applied_patch_subjects"
        then
            continue
        fi

        if git apply --check "$patch" 2>/dev/null
        then
            echo "Applying patch $patch"
            git reset --hard > /dev/null 2>&1
            git apply "$patch"
            git add .
            git commit -m "$patch_basename"
            applied_patch_subjects+=$'\n'"$patch_basename"
        elif git apply --reverse --check "$patch" 2>/dev/null
        then
            continue
        else
            echo "Patch $patch does not apply cleanly in $apply_path" >&2
            git apply --check "$patch"
            exit 1
        fi
    done
done
