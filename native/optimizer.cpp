#include "optimizer.hpp"

#include "html.hpp"
#include "sha256.hpp"

#include <algorithm>
#include <cstdint>
#include <format>
#include <optional>
#include <ranges>
#include <stdexcept>
#include <string_view>

namespace ionix {
namespace {

using ByteCount = std::int64_t;

constexpr std::string_view asset_directory = "_ionix/css/";
constexpr std::size_t class_hash_length = 16;
constexpr std::size_t stylesheet_hash_length = 64;

struct Candidate {
    std::string class_name;
    std::set<std::size_t> pages;
    ByteCount html_savings = 0;
    ByteCount rule_size = 0;
    bool selected = false;
};

using Candidates = std::map<std::string, Candidate, std::less<>>;

[[nodiscard]] std::string asset_path(std::string_view digest) {
    return std::format("{}{}.css", asset_directory, digest);
}

[[nodiscard]] std::string css_rule(std::string_view class_name, std::string_view declarations) {
    return std::format(".{}{{{}}}\n", class_name, declarations);
}

void collect_candidates(const Node& node, std::size_t page_index, Candidates& candidates) {
    if (!node.declarations.empty() && !has_attribute(node, "style")) {
        auto [entry, inserted] = candidates.try_emplace(node.declarations);
        auto& candidate = entry->second;

        if (inserted) {
            candidate.class_name = "ix-" + sha256(node.declarations).substr(0, class_hash_length);
            candidate.rule_size =
                static_cast<ByteCount>(css_rule(candidate.class_name, node.declarations).size());
        }

        const auto inline_size = render_attributes(node).size();
        const auto class_size = render_attributes(node, candidate.class_name).size();

        candidate.html_savings +=
            static_cast<ByteCount>(inline_size) - static_cast<ByteCount>(class_size);
        candidate.pages.insert(page_index);
    }

    for (const auto& child : node.children) {
        collect_candidates(child, page_index, candidates);
    }
}

void validate_class_names(const Candidates& candidates) {
    std::set<std::string_view> names;

    for (const auto& candidate : candidates | std::views::values) {
        if (!names.insert(candidate.class_name).second) {
            throw std::runtime_error("CSS class hash collision");
        }
    }
}

[[nodiscard]] ByteCount marginal_savings(const Candidate& candidate,
                                         const std::set<std::size_t>& linked_pages,
                                         ByteCount link_size) {
    const auto new_links = std::ranges::count_if(
        candidate.pages, [&](std::size_t page) { return !linked_pages.contains(page); });

    return candidate.html_savings - candidate.rule_size -
           static_cast<ByteCount>(new_links) * link_size;
}

[[nodiscard]] std::optional<Candidates::iterator>
best_candidate(Candidates& candidates, const std::set<std::size_t>& linked_pages,
               ByteCount link_size) {
    std::optional<Candidates::iterator> best;
    ByteCount best_savings = 0;

    // map order supplies a tie breaker
    for (auto entry = candidates.begin(); entry != candidates.end(); ++entry) {
        const auto& candidate = entry->second;

        if (candidate.selected) {
            continue;
        }

        const auto savings = marginal_savings(candidate, linked_pages, link_size);

        if (savings > best_savings) {
            best = entry;
            best_savings = savings;
        }
    }

    return best;
}

} // namespace

StylesheetPlan plan_styles(std::span<const Page> pages) {
    Candidates candidates;

    for (const auto [page_index, page] : pages | std::views::enumerate) {
        collect_candidates(page.root, static_cast<std::size_t>(page_index), candidates);
    }

    validate_class_names(candidates);

    StylesheetPlan plan;
    const auto placeholder_path = asset_path(std::string(stylesheet_hash_length, '0'));
    const auto link_size = static_cast<ByteCount>(stylesheet_link(placeholder_path).size());

    while (const auto best = best_candidate(candidates, plan.linked_pages, link_size)) {
        auto& candidate = (*best)->second;
        candidate.selected = true;
        plan.linked_pages.insert_range(candidate.pages);
    }

    for (const auto& [declarations, candidate] : candidates) {
        if (!candidate.selected) {
            continue;
        }

        plan.classes.emplace(declarations, candidate.class_name);
        plan.stylesheet += css_rule(candidate.class_name, declarations);
    }

    if (!plan.stylesheet.empty()) {
        plan.asset_path = asset_path(sha256(plan.stylesheet));
    }

    return plan;
}

} // namespace ionix
