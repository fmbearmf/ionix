#pragma once

#include "model.hpp"

#include <string_view>
#include <vector>

namespace ionix {

// returned pages own their strings
[[nodiscard]] std::vector<Page> parse_manifest(std::string_view source);

} // namespace ionix
