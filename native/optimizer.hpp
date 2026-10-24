#pragma once

#include "model.hpp"

#include <cstddef>
#include <functional>
#include <map>
#include <set>
#include <span>
#include <string>

namespace ionix {

struct StylesheetPlan {
    std::map<std::string, std::string, std::less<>> classes;
    std::set<std::size_t> linked_pages;
    std::string stylesheet;
    std::string asset_path;
};

[[nodiscard]] StylesheetPlan plan_styles(std::span<const Page> pages);

} // namespace ionix
