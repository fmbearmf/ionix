#pragma once

#include "model.hpp"

#include <cstddef>
#include <string>
#include <string_view>

namespace ionix {

struct StylesheetPlan;

[[nodiscard]] bool has_attribute(const Node& node, std::string_view name);

[[nodiscard]] std::string render_attributes(const Node& node,
                                            std::string_view generated_class = {});

[[nodiscard]] std::string stylesheet_link(std::string_view asset_path);

[[nodiscard]] std::string render_document(const Page& page, const StylesheetPlan& plan,
                                          std::size_t page_index);

} // namespace ionix
