#include "html.hpp"

#include "optimizer.hpp"

#include <algorithm>
#include <format>
#include <optional>
#include <ranges>
#include <utility>

namespace ionix {
namespace {

void append_escaped(std::string& output, std::string_view text) {
    for (const char character : text) {
        switch (character) {
        case '&':
            output += "&amp;";
            break;

        case '<':
            output += "&lt;";
            break;

        case '>':
            output += "&gt;";
            break;

        case '"':
            output += "&quot;";
            break;

        case '\'':
            output += "&#39;";
            break;

        default:
            output += character;
            break;
        }
    }
}

void merge_style(std::vector<Attribute>& attributes, std::string_view declarations) {
    const auto existing = std::ranges::find(attributes, "style", &Attribute::name);

    if (existing == attributes.end()) {
        attributes.push_back(Attribute{
            .name = "style",
            .value = std::string{declarations},
        });

        return;
    }

    existing->value = std::string{declarations} + existing->value.value_or("");
}

void merge_class(std::vector<Attribute>& attributes, std::string_view class_name) {
    const auto existing = std::ranges::find(attributes, "class", &Attribute::name);

    if (existing == attributes.end()) {
        attributes.push_back(Attribute{
            .name = "class",
            .value = std::string{class_name},
        });

        return;
    }

    auto combined = existing->value.value_or("");

    if (!combined.empty()) {
        combined += ' ';
    }

    combined += class_name;
    existing->value = std::move(combined);
}

void append_node(std::string& output, const Node& node, const StylesheetPlan& plan,
                 std::string_view asset_path) {
    switch (node.kind) {
    case NodeKind::text:
        append_escaped(output, node.text);
        return;

    case NodeKind::raw:
        output += node.text;
        return;

    case NodeKind::fragment:
        for (const auto& child : node.children) {
            append_node(output, child, plan, asset_path);
        }

        return;

    case NodeKind::element:
        break;
    }

    std::string_view generated_class;

    if (!has_attribute(node, "style")) {
        if (const auto found = plan.classes.find(node.declarations); found != plan.classes.end()) {
            generated_class = found->second;
        }
    }

    output += '<';
    output += node.tag;
    output += render_attributes(node, generated_class);
    output += '>';

    if (node.is_void) {
        return;
    }

    if (node.tag == "head" && !asset_path.empty()) {
        output += stylesheet_link(asset_path);
    }

    for (const auto& child : node.children) {
        append_node(output, child, plan, asset_path);
    }

    output += "</";
    output += node.tag;
    output += '>';
}

} // namespace

bool has_attribute(const Node& node, std::string_view name) {
    return std::ranges::find(node.attributes, name, &Attribute::name) != node.attributes.end();
}

std::string render_attributes(const Node& node, std::string_view generated_class) {
    auto attributes = node.attributes;

    if (!node.declarations.empty()) {
        if (generated_class.empty()) {
            merge_style(attributes, node.declarations);
        } else {
            merge_class(attributes, generated_class);
        }
    }

    std::ranges::sort(attributes, {}, &Attribute::name);
    std::string output;

    for (const auto& attribute : attributes) {
        output += ' ';
        output += attribute.name;

        if (attribute.value) {
            output += "=\"";
            append_escaped(output, *attribute.value);
            output += '"';
        }
    }

    return output;
}

std::string stylesheet_link(std::string_view asset_path) {
    return std::format("<link href=\"/{}\" rel=\"stylesheet\">", asset_path);
}

std::string render_document(const Page& page, const StylesheetPlan& plan, std::size_t page_index) {
    const std::string_view asset_path = plan.linked_pages.contains(page_index)
                                            ? std::string_view{plan.asset_path}
                                            : std::string_view{};

    std::string output = "<!doctype html>\n";
    append_node(output, page.root, plan, asset_path);
    output += '\n';

    return output;
}

} // namespace ionix
