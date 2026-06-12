# Thin wrapper around the west/CMake build system used in Zephyr.
# This is only a task runner, not the build system itself.

SHELL             := /bin/bash
FIND              := find 2>/dev/null
ZENV_PROJECT_ROOT ?= $(CURDIR)
APP_DIR           := $(ZENV_PROJECT_ROOT)/app
TESTS_DIR         := $(ZENV_PROJECT_ROOT)/tests
BUILD_DIR_BASE    := $(ZENV_PROJECT_ROOT)/build
SCRIPTS_DIR       := $(ZEPHYR_WS)/zenv/scripts
BUILD_TYPE        := release
CHECK             := 0
PRESETS_FILE      := $(APP_DIR)/presets.yml

ifeq ("$(wildcard $(PRESETS_FILE))","")
$(error "$(PRESETS_FILE) file not found")
endif

PRESET       := $(shell dasel -p yaml --plain -f $(PRESETS_FILE) presets.[0].name)
FLASH_RUNNER := $(shell dasel -n -p yaml --plain -f $(PRESETS_FILE) "presets.(name=$(PRESET)).flash-runner")

# Quicker way to specify a debug build, e.g. `make DEBUG=1` instead of `make BUILD_TYPE=debug`.
ifeq ($(DEBUG), 1)
    BUILD_TYPE := debug
endif

BUILD_DIR_APP := $(BUILD_DIR_BASE)/app/$(PRESET)/$(BUILD_TYPE)

ifeq ($(CHECK), 1)
    BUILD_DIR_APP := $(BUILD_DIR_APP)/codechecker
endif

BUILD_DIR_TESTS           := $(BUILD_DIR_BASE)/tests
ZENV_WEST_CONFIG          := $(BUILD_DIR_BASE)/west.config
WEST_UPDATED_FILE         := $(ZENV_PROJECT_ROOT)/.west-updated
SUBMANIFESTS_DIRECTORY    := $(ZENV_PROJECT_ROOT)/zephyr/west
WEST_BASE_MANIFEST        := $(ZEPHYR_WS)/west.yml
WEST_MANIFESTS            := $(WEST_BASE_MANIFEST) $(ZENV_PROJECT_ROOT)/west.yml
WEST_MANIFESTS            += $(shell $(FIND) $(SUBMANIFESTS_DIRECTORY) -type f -name "*.yml")
BUILD_CONFIGURED_APP_FILE = $(BUILD_DIR_APP)/build_configured

export ZENV_PROJECT_ROOT
export WEST_CONFIG_LOCAL := $(ZENV_WEST_CONFIG)

.DEFAULT_GOAL := app

.NOTPARALLEL:

$(ZENV_WEST_CONFIG): $(WEST_BASE_MANIFEST) $(ZENV_PROJECT_ROOT)/west.yml
	@mkdir -p $(dir $@)
	@printf '[manifest]\npath = %s\nfile = %s\n\n[zephyr]\nbase = zephyr\n' \
		"$$(realpath --relative-to="$(ZEPHYR_WS)" "$(ZENV_PROJECT_ROOT)")" \
		"$$(realpath --relative-to="$(ZENV_PROJECT_ROOT)" "$(WEST_BASE_MANIFEST)")" \
		> $@

$(WEST_UPDATED_FILE): $(ZENV_WEST_CONFIG) $(WEST_MANIFESTS)
	@echo "Running west update..."
	@west update
	@touch $@

configure-app: $(WEST_UPDATED_FILE) $(PRESETS_FILE)
	@if [ ! -f "$(BUILD_CONFIGURED_APP_FILE)" ]; then \
		set -e; \
		$(SCRIPTS_DIR)/patch.sh; \
		$(SCRIPTS_DIR)/gen_build_config.sh \
		--presets-file=$(PRESETS_FILE) \
		--build-dir=$(BUILD_DIR_APP) \
		--source-dir=$(APP_DIR) \
		--preset=$(PRESET) \
		$(if $(BOARD),--board=$(BOARD)) \
		--build-type=$(BUILD_TYPE) \
		--check=$(CHECK); \
		touch "$(BUILD_CONFIGURED_APP_FILE)"; \
	fi

app: configure-app
	@cd $(BUILD_DIR_APP) && west build

tests: configure-app
	@$(ZEPHYR_BASE)/scripts/twister \
	-T $(TESTS_DIR) \
	-O $(BUILD_DIR_TESTS) \
	$(if $(filter 1,$(RUN)),,-b) \
	$(if $(filter 1,$(RUN)),--enable-valgrind,) \
	-n \
	-c \
	$(if $(TAG),-t $(TAG),) \
	$(if $(TEST),-s $(TEST).test,) \
	$(TWISTER_ARGS)

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
	@rm -f $(WEST_UPDATED_FILE)
	@rm -f $(ZENV_WEST_CONFIG)

# Debugging
print-%:
	@echo '$($*)'

.PHONY: app clean clean-all configure-app flash flash-recover format menuconfig puncover tests
