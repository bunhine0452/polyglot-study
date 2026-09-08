#include <memory>
#include <stdexcept>

std::unique_ptr<int> takeOwnership(std::unique_ptr<int>& source) {
    // source 가 가진 값의 소유권을 std::move 로 가져와 돌려준다.
    // 가져간 뒤에는 source 가 아무것도 가리키지 않아야 한다.
    throw std::runtime_error("여기를 구현해라");
}
