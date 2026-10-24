#include "io.hpp"

#include <format>
#include <fstream>
#include <iterator>
#include <system_error>

namespace ionix {

std::expected<std::string, std::string> read_file(const std::filesystem::path& path) {
    std::ifstream file{path, std::ios::binary};

    if (!file) {
        return std::unexpected{std::format("cannot open '{}'", path.string())};
    }

    std::string content{std::istreambuf_iterator<char>{file}, std::istreambuf_iterator<char>{}};

    if (file.bad()) {
        return std::unexpected{std::format("cannot read '{}'", path.string())};
    }

    return content;
}

std::expected<void, std::string> write_output(const std::filesystem::path& root,
                                              std::string_view relative_path,
                                              std::string_view content) {
    const auto path = root / relative_path;
    std::error_code error;
    std::filesystem::create_directories(path.parent_path(), error);

    if (error) {
        return std::unexpected{
            std::format("cannot create directory for '{}': {}", path.string(), error.message())};
    }

    std::ofstream file{path, std::ios::binary};

    if (!file) {
        return std::unexpected{std::format("cannot open '{}' for writing", path.string())};
    }

    file.write(content.data(), static_cast<std::streamsize>(content.size()));
    file.close();

    if (!file) {
        return std::unexpected{std::format("cannot write '{}'", path.string())};
    }

    return {};
}

} // namespace ionix
