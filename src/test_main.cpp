// main file included in the build by all tests by default

#include "tests/common.h"

int main()
{
    ::testing::InitGoogleTest();
    return RUN_ALL_TESTS();
}
