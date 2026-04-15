# Zephyr development environment container

This repository hosts tools, packages, and various utilities required to run Zephyr RTOS applications inside a Docker container. The base Docker image uses Ubuntu 24.04. The image is built with GitHub Actions for x86-64 and ARM64 architectures. The built image is tagged with the latest commit hash, which makes it easy to pin a specific image version. The latest version can also be pulled with the `latest` tag. For an example of how to use this image and how to structure the required directories and files, see the [ztemplate](https://github.com/paradajz/ztemplate) repository. Custom Zephyr applications and modules can be based on that repository.

  - [Zephyr version and `west.yml`](#zephyr-version-and-westyml)
  - [Patching Zephyr](#patching-zephyr)
  - [Build system](#build-system)
    - [Building application](#building-application)
      - [`name`](#name)
      - [`board`](#board)
      - [`cmake-file`](#cmake-file)
      - [`overlay-file`](#overlay-file)
      - [`conf-files`](#conf-files)
      - [`flash-runner`](#flash-runner)
    - [Building tests](#building-tests)
    - [Code formatting](#code-formatting)
    - [Code checking](#code-checking)
    - [Flashing application](#flashing-application)

## Zephyr version and `west.yml`

The container contains the Zephyr SDK and the base [Zephyr repository](https://github.com/zephyrproject-rtos/zephyr), which avoids the need for applications to clone Zephyr every time the container is opened. The Zephyr version is specified in the `west.yml` file in this repository. Any additional repositories required by an application need to be specified in the application's own `west.yml` file located in its root directory.

## Patching Zephyr

This repository contains the scripting needed to patch any Git repository inside the `$ZEPHYR_WS` directory. To use it, add `.patch` files under the following directory in the application root directory:

```
<application>
└── zephyr
    ├── patch
```

To patch a Git repository inside `$ZEPHYR_WS`, create the patch file under the same directory hierarchy that the target repository uses inside `$ZEPHYR_WS`. For example, to patch the `$ZEPHYR_WS/zephyr` repository, create the patch under `<application>/zephyr/patch/zephyr/`, for example as `<application>/zephyr/patch/zephyr/patch_name.patch`. There is no limit to the number of patches, and patch names can be arbitrary. If patches need to be applied in a specific order, prefix the filenames with `00n-`, where `n` indicates the patch number. The build system will automatically discover and apply patches that have not already been applied.

## Build system

Normally, Zephyr applications use CMake via the `west` meta tool. Managing multiple application configurations through command-line options for `west build` can quickly become cumbersome. This repository includes a base `Makefile` that acts as a thin wrapper around various CMake and `west` commands and is not a build system in itself.

### Building application

To simplify building multiple application configurations further, this repository supports a custom `presets.yml` configuration file that must be placed in the `<application>/app` directory. Below is an example of such a file:

```
---
presets:
  -
    name: "default"
    board: "nucleo_f767zi"
    cmake-file: "default.cmake"
    overlay-file: "nucleo_f767zi.overlay"
    conf-files:
      common:
        - "common.conf"
      release:
        - "release.conf"
      debug:
        - "debug.conf"
    flash-runner: "openocd"
```

`presets.yml` is a YAML file that is automatically parsed when the `make` command is run inside the application repository. Parsing `presets.yml` generates a corresponding `west build` command, which is then run via `make`. Note that the generated build command enables sysbuild by default.

Kconfig options can be enabled for all presets by default. To do so, create a `app/global.conf` file in the application repository and list the options there. The options will be automatically be added to the build.

#### `name`

Specifies the preset name. The name should be passed to the `PRESET` variable in Makefile, e.g.:

```
make PRESET=default
```

This builds the `default` application preset.

Note: the first preset in `presets.yml` is the default value for the `PRESET` variable in the Makefile. Therefore, `make` and `make PRESET=default` are equivalent.

#### `board`

The `board` key sets the board to build the application for. To see the available boards, run `west boards`.

#### `cmake-file`

Sets the CMake file that defines the build configuration for a preset. The path is relative to the `app` directory. The base `CMakeLists.txt` in the `app` directory must exist but only includes boilerplate required for the Zephyr build system and the `presets.yml` support and also to include the specified `cmake-file`. See the [ztemplate repository](https://github.com/paradajz/ztemplate/blob/master/app/CMakeLists.txt) for an example. It's recommended, though not required, to name the file after the preset.

#### `overlay-file`

Device tree overlay for a preset. The path is relative to the `app` directory.

#### `conf-files`

Defines configuration files under three categories:

* `common:`: a list of configs used in both release and debug builds.
* `release:`: a list of configs used only in release builds (default).
* `debug:`: a list of configs used only in debug builds.

Paths are relative to the `app` directory. By default, the release configuration is used. This is controlled via the `make` variable `DEBUG`. This variable is set to `0` by default, which means the debug configuration is not enabled and the release configuration is used instead. When this variable is set to `1`, the debug configuration is built with debug optimizations enabled. An example of how to build the default preset in debug configuration:

```
make PRESET=default DEBUG=1
```

There is no need to call make with `DEBUG=0` since that is already the default.

#### `flash-runner`

Defines the flashing tool used when flashing the board with `make flash` (see [Flashing application](#flashing-application)). If not specified, the default tool for the specified board will be used, as defined in the Zephyr repository. **Note:** tools such as `JLink` or `STM32CubeProgrammer` are not part of the image due to redistribution restrictions. Those tools can be installed in the container, or `openocd` can be used instead because it is part of the Zephyr SDK.

### Building tests

For tests, the Twister test runner from the Zephyr project is used. Tests should be added under the `<application>/tests/src` directory:

```
<application>
└── tests
    ├── src
```

From a Zephyr standpoint, a test is just a regular application. Like a normal application, a test requires `CMakeLists.txt` but also a `testcase.yaml` file. An example `CMakeLists.txt` for a test can be seen in the [ztemplate repository](https://github.com/paradajz/ztemplate/blob/master/tests/src/dummy/CMakeLists.txt). For more information about the `testcase.yaml` file, check the [official Zephyr documentation](https://docs.zephyrproject.org/latest/develop/test/twister.html). To build all tests, run the following:

```
make tests
```

This will only build the tests, but will not run them. To run them as well, run the following:

```
make tests RUN=1
```

To run a single test only, run the following:

```
make tests RUN=1 TEST=<test_name>
```

To run a test tag group, run the following:

```
make tests RUN=1 TAG=<tag>
```

By default, tests are run through Valgrind to detect possible memory leaks.

Kconfig options can be enabled for all tests by default. To do so, create a `tests/global.conf` file in the application repository and list the options there. The options will be automatically be added to the build.

### Code formatting

Code is formatted using `clang-format` in Allman style by default. The code formatting rules are defined in `clang-format/.clang-format` file. Users can use alternative rules. To do so, create a `.clang-format` file in the root directory of the application repository and list the formatting rules there.

To format the code run the following:

```
make format
```

In the [template repository](https://github.com/paradajz/ztemplate), each file is automatically formatted when saved if Visual Studio Code is used.

### Code checking

Code is checked with `CodeChecker`, a static analysis tool built on the LLVM/Clang toolchain. To check the code, run the following:

```
make CHECK=1
```

To check which rules are enabled, see the `.codechecker.yml` file in the `codechecker` directory. The rules can be overridden in the application by creating a `.codechecker.yml` file in the root directory of the application repository. For more details, check the [official CodeChecker documentation](https://codechecker.readthedocs.io/en/latest/analyzer/user_guide/).

### Flashing application

To flash the application to a board, simply run:

```
make flash
```

This will flash the default preset. To flash any other preset, run the following (with `preset_name` being the correct name defined in `presets.yml` file):

```
make flash PRESET=preset_name
```
