#!/bin/bash

# Format the application code with clang-format.
# The script checks whether a .clang-format file exists in the application
# directory and uses it if it does. Otherwise, a file from this repository
# is used. The script will return an error if any changes exist in the
# directories where the application code is located.

cd "$ZEPHYR_PROJECT" || exit 1

clang_format_file=${ZEPHYR_WS}/zenv/clang-format/.clang-format
user_clang_format_file=${ZEPHYR_PROJECT}/.clang-format
paths=("app" "module" "tests")

if [[ -f $user_clang_format_file ]]
then
    clang_format_file=$user_clang_format_file
fi

find "$ZEPHYR_PROJECT" \
-regex '.*\.\(cpp\|hpp\|h\|cc\|cxx\|c\)' \
-not -path '**build/**/*' \
-exec clang-format -style=file:"$clang_format_file" -i {} +

git diff -- "${paths[@]}"
git diff -s --exit-code -- "${paths[@]}"
