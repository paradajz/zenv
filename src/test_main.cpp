/*
 * Copyright (c) 2026 Igor Petrovic
 * SPDX-License-Identifier: MIT
 */

// main file included in the build by all tests by default

#include <gtest/gtest.h>
#include <gmock/gmock.h>

int main()
{
    ::testing::InitGoogleTest();
    return RUN_ALL_TESTS();
}
