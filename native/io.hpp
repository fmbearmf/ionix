#pragma once

#include <expected>
#include <filesystem>
#include <string>
#include <string_view>

namespace ionix {

[[nodiscard]] std::expected<std::string, std::string> read_file(const std::filesystem::path& path);

[[nodiscard]] std::expected<void, std::string> write_output(const std::filesystem::path& root,
                                                            std::string_view relative_path,
                                                            std::string_view content);

} // namespace ionix
