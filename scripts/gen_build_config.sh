#!/bin/bash

# Parse the provided YAML file, generate a CMake-only west build
# command and execute it.

for arg in "$@"
do
    case "$arg" in
        --presets-file=*)
            presets_file=${arg#--presets-file=}
            ;;
        --build-dir=*)
            build_dir=${arg#--build-dir=}
            ;;
        --source-dir=*)
            source_dir=${arg#--source-dir=}
            ;;
        --preset=*)
            preset=${arg#--preset=}
            ;;
        --board=*)
            board_override=${arg#--board=}
            ;;
        --build-type=*)
            build_type=${arg#--build-type=}
            ;;
        --check=*)
            check=${arg#--check=}
            ;;
    esac
done

echo "Generating west build command..."

yaml_parser="dasel -n -p yaml --plain -f"

west_cmd="west build --build-dir $build_dir -s $source_dir --cmake-only --sysbuild "

if [[ ! -f $presets_file ]]
then
    echo "$presets_file not found"
    exit 1
fi

if [[ $($yaml_parser "$presets_file" "presets.(name=${preset})") == "null" ]]
then
    echo "Preset $preset not found in $presets_file"
    exit 1
fi

if [[ -n $board_override ]]
then
    board=$board_override
else
    board=$($yaml_parser "$presets_file" "presets.(name=${preset}).board")
fi

if [[ ($board != "null") && (-n $board) ]]
then
    west_cmd+="-b $board "
fi

cmake_file=$($yaml_parser "$presets_file" "presets.(name=${preset}).cmake-file")

if [[ ($cmake_file != "null") && (-n $cmake_file) ]]
then
    west_cmd+="-DPRESET_CMAKE_FILE=${source_dir}/${cmake_file} "
fi

west_cmd+=" -- "
west_cmd+="-DPRESET_NAME=${preset} "

user_global_conf_file="${ZEPHYR_PROJECT}/app/global.conf"
conf_file_started=0

if [[ -f $user_global_conf_file ]]
then
    west_cmd+="-DCONF_FILE=${user_global_conf_file}"
    conf_file_started=1
fi

append_config_files()
{
    local conf_type
    local nr_of_config_files
    local i

    conf_type=$1
    nr_of_config_files=$($yaml_parser "$presets_file" "presets.(name=${preset}).conf-files.$conf_type" --length)

    for ((i = 0; i < nr_of_config_files; i++))
    do
        conf_file=$($yaml_parser "$presets_file" "presets.(name=${preset}).conf-files.$conf_type.[$i]")

        if [[ ($conf_file != "null") && (-n $conf_file) ]]
        then
            if [[ $conf_file_started -eq 0 ]]
            then
                west_cmd+="-DCONF_FILE=${source_dir}/${conf_file}"
                conf_file_started=1
            else
                # When there are multiple config files, a list value needs to be passed to CMake which is normally separated
                # with ; character. Since the passing occurs via CLI, ; needs to be escaped.
                west_cmd+="\;"
                west_cmd+=${source_dir}/${conf_file}
            fi
        fi
    done
}

append_config_files "common"
append_config_files "$build_type"

west_cmd+=" "

overlay=$($yaml_parser "$presets_file" "presets.(name=${preset}).overlay-file")

if [[ ($overlay != "null") && (-n $overlay) ]]
then
    west_cmd+="-DDTC_OVERLAY_FILE=$overlay "
fi

if [[ $build_type == "debug" ]]
then
    west_cmd+="-DCONFIG_DEBUG_OPTIMIZATIONS=y "
fi

if [[ $check -eq 1 ]]
then
    config_file=${ZEPHYR_WS}/zenv/codechecker/.codechecker.yml
    user_config_file=${ZEPHYR_PROJECT}/.codechecker.yml

    if [[ -f $user_config_file ]]
    then
        config_file=$user_config_file
    fi

    # When checking the code, disable the logging due to many clang-tidy warnings
    west_cmd+="-DZEPHYR_SCA_VARIANT=codechecker -DCODECHECKER_CONFIG_FILE=$config_file -DCODECHECKER_EXPORT=html -DCODECHECKER_PARSE_EXIT_STATUS=1 -DCONFIG_LOG=n"
fi

echo "Build command is:
$west_cmd"

$west_cmd
