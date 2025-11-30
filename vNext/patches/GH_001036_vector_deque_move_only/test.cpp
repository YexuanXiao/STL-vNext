// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include <deque>
#include <vector>

struct A {
    A(const A&) = delete;
};

void f() {
    std::vector<std::deque<A>> q;
    q.resize(4);
}

int main() {
    f();
    return 0;
}
