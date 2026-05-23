if(EXISTS "$ENV{ZENV_PROJECT_ROOT}/tests/global.conf")
    list(APPEND CONF_FILE "$ENV{ZENV_PROJECT_ROOT}/tests/global.conf")
endif()

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
    $ENV{ZENV_PROJECT_ROOT}/tests/include
)
