// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include <array>
#include <cassert>
#include <type_traits>

struct X {
    X() {
        assert(false);
    }
};

int main() {
    std::array<X, 0> arr;
    (void) arr;
    static_assert(std::is_trivially_constructible_v<std::array<int, 0>>);
    static_assert(std::is_trivially_copyable_v<std::array<int, 0>>);
    // disable by BUG 1
    // static_assert(!std::is_copy_assignable_v<std::array<const int, 0>>);
}
