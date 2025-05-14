set(GLOBAL_CONF_FILE "$ENV{ZEPHYR_WS}/zenv/kconfig/test.conf")

if(EXISTS "$ENV{ZEPHYR_PROJECT}/test/global.conf")
    set(GLOBAL_CONF_FILE "$ENV{ZEPHYR_PROJECT}/test/global.conf")
endif()

list(APPEND CONF_FILE "${GLOBAL_CONF_FILE}")
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

target_sources(app
    PRIVATE
    $ENV{ZEPHYR_WS}/zenv/src/test_main.cpp
)

target_link_libraries(app
    PUBLIC
    pthread
    gmock
    gtest
)

target_include_directories(app
    PRIVATE
    $ENV{ZEPHYR_PROJECT}/tests/include
)
