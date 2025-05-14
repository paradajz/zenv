# Thin wrapper around west/cmake build system used in Zephyr for simpler usage.
# This is used as task runner only, not as the build system.

SHELL          := /bin/bash
FIND           := find 2>/dev/null
APP_DIR        := $(ZEPHYR_PROJECT)/app
TESTS_DIR      := $(ZEPHYR_PROJECT)/tests
BUILD_DIR_BASE := $(ZEPHYR_PROJECT)/build
SCRIPTS_DIR    := $(ZEPHYR_WS)/zenv/scripts
BUILD_TYPE     := release
CHECK          := 0
PRESETS_FILE   := $(APP_DIR)/presets.yml

ifeq ("$(wildcard $(PRESETS_FILE))","")
$(error "$(PRESETS_FILE) file not found")
endif

PRESET       := $(shell dasel -p yaml --plain -f $(PRESETS_FILE) presets.[0].name)
FLASH_RUNNER := $(shell dasel -n -p yaml --plain -f $(PRESETS_FILE) "presets.(name=$(PRESET)).flash-runner")

# Quicker way of specifying debug build, eg. make DEBUG=1 compared to make BUILD_TYPE=debug
ifeq ($(DEBUG), 1)
    BUILD_TYPE := debug
endif

BUILD_DIR_APP := $(BUILD_DIR_BASE)/app/$(PRESET)/$(BUILD_TYPE)

ifeq ($(CHECK), 1)
    BUILD_DIR_APP := $(BUILD_DIR_APP)/codechecker
endif

BUILD_DIR_TESTS           := $(BUILD_DIR_BASE)/tests
WEST_UPDATED_FILE         := .west-updated
SUBMANIFESTS_DIRECTORY    := $(ZEPHYR_PROJECT)/zephyr/west
WEST_MANIFESTS            := west.yml
WEST_MANIFESTS            += $(shell $(FIND) $(SUBMANIFESTS_DIRECTORY) -type f -name "*.yml")
BUILD_CONFIGURED_APP_FILE := $(BUILD_DIR_APP)/build_configured

.DEFAULT_GOAL := app

.NOTPARALLEL:

$(WEST_UPDATED_FILE): $(WEST_MANIFESTS)
	@echo "Running west update..."
	@west update
	@touch $@

$(BUILD_CONFIGURED_APP_FILE): $(WEST_UPDATED_FILE) $(PRESETS_FILE)
	@$(SCRIPTS_DIR)/patch.sh
	@$(SCRIPTS_DIR)/gen_build_config.sh \
	--presets-file=$(PRESETS_FILE) \
	--build-dir=$(BUILD_DIR_APP) \
	--source-dir=$(APP_DIR) \
	--preset=$(PRESET) \
	--build-type=$(BUILD_TYPE) \
	--check=$(CHECK)
	@touch $@

app: $(BUILD_CONFIGURED_APP_FILE)
	@cd $(BUILD_DIR_APP) && west build
	@cp $(BUILD_DIR_APP)/app/compile_commands.json $(ZEPHYR_PROJECT)/compile_commands.json # For VSCode

tests:
ifeq ($(RUN),1)
	@$(ZEPHYR_BASE)/scripts/twister -T $(TESTS_DIR) -O $(BUILD_DIR_TESTS) -n --enable-valgrind
else
	@$(ZEPHYR_BASE)/scripts/twister -T $(TESTS_DIR) -O $(BUILD_DIR_TESTS) -b -n
endif

flash: app
ifeq ($(FLASH_RUNNER),null)
	@cd $(BUILD_DIR_APP) && west flash
else
	@cd $(BUILD_DIR_APP) && west flash --runner $(FLASH_RUNNER)
endif

flash-recover: app
ifeq ($(FLASH_RUNNER),null)
	@cd $(BUILD_DIR_APP) && west flash --recover
else
	@cd $(BUILD_DIR_APP) && west flash --recover --runner $(FLASH_RUNNER)
endif

format:
	@$(ZEPHYR_WS)/zenv/scripts/code_format.sh

menuconfig: $(BUILD_CONFIGURED_APP_FILE)
	@cd $(BUILD_DIR_APP) && west build -t menuconfig

puncover: app
	@cd $(BUILD_DIR_APP)/app && west build -t puncover

clean:
	@echo Cleaning up.
	@rm -rf $(BUILD_DIR_BASE)

clean-all:
	@echo Cleaning up.
	@rm -rf $(BUILD_DIR_BASE)
	@rm -rf $(CCACHE_DIR)
	@$(SCRIPTS_DIR)/cleanup.sh

# Debugging
print-%:
	@echo '$($*)'

.PHONY: app tests flash flash-recover format menuconfig puncover clean clean-all
