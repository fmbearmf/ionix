#pragma once

#include <string>
#include <string_view>

namespace ionix {

[[nodiscard]] std::string sha256(std::string_view input);

} // namespace ionix
