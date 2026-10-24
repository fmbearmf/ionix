#include "html.hpp"
#include "io.hpp"
#include "manifest.hpp"
#include "optimizer.hpp"

#include <cstddef>
#include <cstdio>
#include <exception>
#include <expected>
#include <filesystem>
#include <print>
#include <ranges>
#include <span>
#include <string>

namespace {

[[nodiscard]] std::expected<void, std::string> run(std::span<char*> arguments) {
    if (arguments.size() != 3) {
        return std::unexpected{"usage: ionix-css MANIFEST OUTPUT-DIRECTORY"};
    }

    const auto source = ionix::read_file(arguments[1]);

    if (!source) {
        return std::unexpected{source.error()};
    }

    const auto pages = ionix::parse_manifest(*source);
    const auto plan = ionix::plan_styles(pages);
    const std::filesystem::path output_directory{arguments[2]};

    if (!plan.asset_path.empty()) {
        const auto result = ionix::write_output(output_directory, plan.asset_path, plan.stylesheet);

        if (!result) {
            return result;
        }
    }

    for (const auto [page_index, page] : pages | std::views::enumerate) {
        const auto html = ionix::render_document(page, plan, static_cast<std::size_t>(page_index));
        const auto result = ionix::write_output(output_directory, page.path, html);

        if (!result) {
            return result;
        }
    }

    return {};
}

} // namespace

int main(int argc, char** argv) {
    try {
        const auto result = run(std::span{argv, static_cast<std::size_t>(argc)});

        if (!result) {
            std::println(stderr, "ionix-css: {}", result.error());
            return 1;
        }

        return 0;
    } catch (const std::exception& error) {
        std::println(stderr, "ionix-css: {}", error.what());
        return 1;
    }
}
