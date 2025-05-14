# Zephyr development environment container

This repository hosts tools, packages and various utilities required to run Zephyr RTOS applications inside a Docker container. The base Docker image is based on Ubuntu 24.04. The image is built with GitHub Actions for x86-64 and ARM64 architectures. The built image is tagged with the latest commit hash, making pinning to specific image version simple. Latest version can also be pulled with the `latest` tag. For example usage of this image and the required directory/file structure see the [ztemplate](https://github.com/paradajz/ztemplate) repository. Custom Zephyr applications and modules can be based on that repository.

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
  - [`zephyr_app_library` and `zephyr_app_library_named` support](#zephyr_app_library-and-zephyr_app_library_named-support)

## Zephyr version and `west.yml`

The container contains the Zephyr SDK and base [Zephyr repository](https://github.com/zephyrproject-rtos/zephyr), avoiding the need for applications to clone Zephyr every time the container is opened. Zephyr version is specified in `west.yml` file inside this repository. Any additional repositories required for the application need to be specified in application's own `west.yml` file located in its root directory.

## Patching Zephyr

This repository contains scripting needed to patch any Git repository inside `$ZEPHYR_WS` directory. To use it, add `.patch` files to the following directory in the application root directory:

```
<application>
└── zephyr
    ├── patch
```

To patch a Git repository inside the `$ZEPHYR_WS`, create the patch file under the same directory hierarchy as in `$ZEPHYR_WS`. For example, to patch `$ZEPHYR_WS/zephyr` repository, first, go to the application directory above (`zephyr/patch`), then create a matching directory structure like under `$ZEPHYR_WS`, so for the `zephyr` repository itself that would simply be a directory named `zephyr`. The full path is then `<application>/zephyr/patch/zephyr/patch_name.patch`. There is no limit to the number of patches, and the patch names can be arbitrary. If patching in specific order is required, prefix filenames with `00n-`, where `n` indicates the patch number (and with it, the patch order). The build system will automatically discover and apply patches that haven't already been applied.

## Build system

Normally, Zephyr applications use CMake via the `west` meta tool. Managing various application configurations via command line options to `west build` applications can quickly become cumbersome. This repository includes a base `Makefile` file that acts as a thin wrapper around various CMake and `west` commands and is not a build system in itself.

### Building application

To simplify building of various application configurations further, this repository supports a custom `presets.yml` configuration file that must be placed in `<application>/app` directory. Below is an example of such file:

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

`presets.yml` is a YAML file automatically parsed when `make` command is run inside the application repository. Parsing of `presets.yml` generates a corresponding `west build` command which is then run via `make` command. Note that the generated build command will enable sysbuild by default.

Some Kconfig options are enabled for all presets by default. These are defined in `kconfig/app.conf` file. Users can use alternative common options. To do so, create an `app/global.conf` file in the application repository and list the options there.

#### `name`

Specifies the preset name. The name should be passed to the `PRESET` variable in Makefile, e.g.:

```
make PRESET=default
```

This builds the `default` application preset.

Note: the first preset in `presets.yml` is the default value for the `PRESET` variable inside Makefile. Therefore, `make` and `make PRESET=default` are equivalent.

#### `board`

`board` key sets the board for which to build application. To see available boards, run `west boards`.

#### `cmake-file`

Sets the CMake file that defines the build configuration for a preset. The path is relative to the `app` directory. The base `CMakeLists.txt` in the `app` directory must exist but only includes boilerplate required for the Zephyr build system and the `presets.yml` support and also to include the specified `cmake-file`. See the [ztemplate repository](https://github.com/paradajz/ztemplate/blob/master/app/CMakeLists.txt) for an example. It's recommended, though not required, to name the file after the preset.

#### `overlay-file`

Device tree overlay for a preset. The path is relative to the `app` directory.

#### `conf-files`

Defines configuration files under three categories:

* `common:`: a list of configs used in both release and debug builds.
* `release:`: a list of configs used only in release builds (default).
* `debug:`: a list of configs used only in debug builds.

Paths are relative to the `app` directory. By default, the release configuration is used. This is controlled via `make` variable `DEBUG`. This variable is by default set to `0`, meaning that debug configuration isn't enabled - in other words, release configuaration is. When this variable is set to `1`, debug configuration is built with debug optimizations enabled. An example of how to built the default preset in debug configuration:

```
make PRESET=default DEBUG=1
```

There is no need to call make with `DEBUG=0` since that is already the default.

#### `flash-runner`

Defines the flashing tool used when flashing the board with `make flash` (see: [Flashing application](#flashing-application)). If not specified, the default tool for the specifed board will be used (defined in the Zephyr repository). **Note:** tools such as `JLink` or `STM32CubeProgrammer` aren't part of the image due to the redistribution restrictions. Those tools can be installed in the container or `openocd` can be used (part of the Zephyr SDK).

### Building tests

For tests, Twister test runner from the Zephyr project is used. Tests should be added inside the `<application>/tests/src` directory:

```
<application>
└── tests
    ├── src
```

From a Zephyr standpoint, a test is just a regular application. Just like a normal application, a test requires `CMakeLists.txt` but also `testcase.yaml` file. `CMakeLists.txt` example for a test can be seen in the [ztemplate repository](https://github.com/paradajz/ztemplate/blob/master/tests/src/dummy/CMakeLists.txt). For more info on the `testcase.yaml` file check the [official Zephyr documentation](https://docs.zephyrproject.org/latest/develop/test/twister.html). To build all the tests run the following:

```
make tests
```

This will only build the tests, but will not run them. To run them as well, run the following:

```
make tests RUN=1
```

By default, tests are run through Valgrind to detect possible memory leaks.

Some Kconfig options are enabled for all tests by default. These are defined in `kconfig/test.conf` file. Users can use alternative common options. To do so, create a `tests/global.conf` file in the application repository and list the options there.

### Code formatting

Code is formatted using `clang-format` in Allman style by default. The code formatting rules are defined in `clang-format/.clang-format` file. Users can use alternative rules. To do so, create a `.clang-format` file in the root directory of the application repository and list the formatting rules there.

To format the code run the following:

```
make format
```

In the [template repository](https://github.com/paradajz/ztemplate), each file is automatically formatted when saved if Visual Studio Code is used.

### Code checking

Code is checked with `CodeChecker`, a static analysis tool built on LLVM/Clang toolchain. To check the code run the following:

```
make CHECK=1
```

To check which rules are enabled, see `.codechecker.yml` file inside `codechecker` directory. The rules can be overriden in the application by creating a `.codechecker.yml` file in the root directory of the application repository. For more details, check the [official CodeChecker documentation](https://codechecker.readthedocs.io/en/latest/analyzer/user_guide/).

### Flashing application

To flash the application to a board, simply run:

```
make flash
```

This will flash the default preset. To flash any other preset, run the following (with `preset_name` being the correct name defined in `presets.yml` file):

```
make flash PRESET=preset_name
```

## `zephyr_app_library` and `zephyr_app_library_named` support

Zephyr includes CMake macros `zephyr_library` and `zephyr_library_named` to make it simpler to define a static Zephyr library. The first macro will infer the library name from its directory structure and the second accepts the name argument. If the Zephyr application is composed of multiple libraries, each of those libraries needs to be manually listed in `target_link_libraries(app)`. When using `zephyr_app_library` and `zephyr_library_named`, the library name is appended to a global CMake property called `ZEPHYR_APP_LIBS` so that application-level libraries can be linked more easily:

```
get_property(app_libs GLOBAL PROPERTY ZEPHYR_APP_LIBS)

target_link_libraries(app
    PUBLIC
    ${app_libs}
)
```

Support for these two macros is added via a patch (see `zephyr/patch/zephyr/zephyr_app_library.patch`). See [Patching Zephyr](#patching-zephyr) section for more information.
