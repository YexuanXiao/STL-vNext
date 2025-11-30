// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include <array>
#include <cassert>

struct X {
    X() {
        assert(false);
    }
};

int main() {
    std::array<X, 0> arr;
    (void) arr;

    static_assert(std::is_trivially_constructible_v<std::array<int, 0>>);
}
