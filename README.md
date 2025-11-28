# STL Community vNext

A personally maintained vNext version of the Microsoft STL. Due to Microsoft's business strategy, the STL will not release a vNext version until at least the next major release (VS19). Therefore, it's time for the community to provide a solution to fix some of the bugs in the STL.

## Goals

- Fix the genuinely broken parts of the STL.
- **No new features** will be added on top of the STL.
- All changes are **header-only**, requiring no additional build or deployment steps.
- Strict standard conformance is **non-goal**. Minor non-conformance issues may remain unfixed to simplify maintenance.

If you find the project useful, be sure to **vote for vNext** in the [Developer Community](https://developercommunity.visualstudio.com/t/C-MSVC-Toolset-ABI-Break-:-Next-Stable/10769087) and don't forget to **share it** with others.

## Advantages

**No dependencies**, **no need to modify source code**. The high-quality implementations provided by this project are more standards-compliant **than** Microsoft STL and sometimes **even** outperform libc++ and libstdc++ (which are also ABI-constrained).

For more information, see [#3](https://github.com/YexuanXiao/STL-vNext/issues/3).

## Requirements

- **C++20 or later** is required for avoid the need for `enable_if` and `void_t` idioms.

## ABI Stability

This project is **always ABI-unstable**.

To avoid ODR violations:

- Ensure all files using C++ interfaces include the headers provided by this project.
- Ensure the same version of this project is used.
- Use the same compile options across the entire program whenever possible.

## Roadmap

The following is a list of problems that this project will fix:

- ✅ [`<deque>` : A `deque<T>` where `T` is move-only, when nested in vector, does not compile](https://github.com/microsoft/STL/issues/1036)
- ✅ [`<deque>`: Needs a major performance overhaul](https://github.com/microsoft/STL/issues/147)
- ✅ [special_math.cpp: Statically linked library contains and depends on Boost symbols](https://github.com/microsoft/STL/issues/362)
- ❎ [`<array>`: `std::array<T,0>` calls constructors and destructors of `T`](https://github.com/microsoft/STL/issues/5583)
- ❎ [Reconsider `vector<bool>` underlying type](https://github.com/microsoft/STL/issues/5348)
- ❎ [`<functional>`: better hash function](https://github.com/microsoft/STL/issues/2360)
- ❎ [LWG-3120 Unclear behavior of `monotonic_buffer_resource::release()`](https://github.com/microsoft/STL/issues/1468)
- ❎ [`<mutex>`: change `mutex` to be an SRWLOCK](https://github.com/microsoft/STL/issues/946)
- ❎ [`<string>`: Consider retuning the Small String Optimization](https://github.com/microsoft/STL/issues/295)
- ❎ [`<chrono>`: Major performance issues when using zoned_time or time_zone](https://github.com/microsoft/STL/issues/2842)

Other bugs may also be considered for fixes if justified, though the listed bugs remain the top priority.

## Relationship with Microsoft STL

- This project will always remain a **downstream** of the Microsoft STL.
- If Microsoft decides to develop the STL vNext, this project will have fulfilled its mission, and its code may be backported to the Microsoft STL.

## Contributing

This project welcomes contributions from anyone and is licensed under the **Apache-2.0 WITH LLVM-exception** license, the same as Microsoft STL.

All development work is conducted on the dev branch.

Before contributing, you should have a solid understanding of the C++ standard (for example, by reading [the C++ standard draft](https://eel.is/c++draft) or [C++ Reference](https://en.cppreference.com/)), and cite relevant sections when necessary.

The build and testing process for this project is identical to Microsoft STL. Before submitting a Pull Request, ensure all tests pass against the Microsoft STL test suite.

## Release rule

This project synchronizes with each Visual Studio update based on the [STL Changelog](https://raw.githubusercontent.com/wiki/microsoft/STL/Changelog.md). Prior to each Visual Studio update to the STL, a release of that version of the STL will be published.

## Disclaimer

Microsoft is a trademark of Microsoft Corporation. The maintainer of this project is not a Microsoft employee, nor is this project sponsored by Microsoft in any way.
