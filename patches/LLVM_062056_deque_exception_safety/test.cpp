#include <cassert>
#include <deque>

template <int N>
struct ThrowingCopy {
    static int created_by_copying;
    static int destroyed;

    ThrowingCopy() = default;
    ~ThrowingCopy() {
        ++destroyed;
    }

    ThrowingCopy([[maybe_unused]] const ThrowingCopy& other) {
        ++created_by_copying;
        if (created_by_copying == N) {
            throw -1;
        }
    }
};

template <int N>
int ThrowingCopy<N>::created_by_copying = 0;
template <int N>
int ThrowingCopy<N>::destroyed = 0;

int main() {
    using T = ThrowingCopy<3>;
    T in[5];

    try {
        std::deque<T> c(in, in + 5);
        assert(false); // The constructor call above should throw.

    } catch (int) {
        assert(T::created_by_copying == 3);
        assert(T::destroyed == 2); // No destructor call for the partially-constructed element.
    }
}
