#include "manifest.hpp"

#include <charconv>
#include <cstddef>
#include <format>
#include <set>
#include <span>
#include <stdexcept>
#include <string>
#include <system_error>
#include <utility>
#include <variant>

namespace ionix {
namespace {

// 2 alternatives: a string or a recursive list
struct Value {
    using List = std::vector<Value>;
    std::variant<std::string_view, List> data;

    [[nodiscard]] std::string_view text() const {
        if (const auto* value = std::get_if<std::string_view>(&data)) {
            return *value;
        }

        throw std::runtime_error("expected manifest string");
    }

    [[nodiscard]] std::span<const Value> list() const {
        if (const auto* values = std::get_if<List>(&data)) {
            return *values;
        }

        throw std::runtime_error("expected manifest list");
    }

    [[nodiscard]] std::span<const Value> fields(std::size_t count) const {
        const auto values = list();

        if (values.size() != count) {
            throw std::runtime_error("invalid manifest field count");
        }

        return values;
    }
};

class Parser {
  public:
    explicit Parser(std::string_view source) : source_(source) {}

    [[nodiscard]] Value parse() {
        auto result = parse_value(0);

        if (position_ != source_.size()) {
            fail("trailing manifest data");
        }

        return result;
    }

  private:
    static constexpr unsigned maximum_depth = 1024;

    std::string_view source_;
    std::size_t position_ = 0;

    [[noreturn]] void fail(std::string_view message) const {
        throw std::runtime_error(std::format("{} at byte {}", message, position_));
    }

    [[nodiscard]] Value parse_value(unsigned depth) {
        if (depth > maximum_depth || position_ == source_.size()) {
            fail("invalid manifest nesting");
        }

        if (source_[position_] == '[') {
            return parse_list(depth);
        }

        return parse_string();
    }

    [[nodiscard]] Value parse_list(unsigned depth) {
        Value::List values;
        ++position_;

        while (position_ < source_.size() && source_[position_] != ']') {
            values.push_back(parse_value(depth + 1));
        }

        if (position_ == source_.size()) {
            fail("unterminated manifest list");
        }

        ++position_;
        return Value{std::move(values)};
    }

    [[nodiscard]] Value parse_string() {
        const auto separator = source_.find(':', position_);

        if (separator == std::string_view::npos) {
            fail("missing manifest string length");
        }

        const auto digits = source_.substr(position_, separator - position_);
        std::size_t length = 0;
        const auto [end, error] =
            std::from_chars(digits.data(), digits.data() + digits.size(), length);

        if (error != std::errc{} || end != digits.data() + digits.size()) {
            fail("invalid manifest string length");
        }

        position_ = separator + 1;

        if (length > source_.size() - position_) {
            fail("manifest string exceeds remaining input");
        }

        const auto text = source_.substr(position_, length);
        position_ += length;

        return Value{text};
    }
};

[[nodiscard]] Attribute decode_attribute(const Value& value) {
    const auto fields = value.list();

    if (fields.size() == 1) {
        return Attribute{.name = std::string{fields[0].text()}, .value = std::nullopt};
    }

    if (fields.size() == 2) {
        return Attribute{
            .name = std::string{fields[0].text()},
            .value = std::string{fields[1].text()},
        };
    }

    throw std::runtime_error("invalid attribute field count");
}

[[nodiscard]] Node decode_node(const Value& value) {
    const auto fields = value.list();

    if (fields.empty()) {
        throw std::runtime_error("missing node kind");
    }

    const auto kind = fields[0].text();
    Node node;

    if (kind == "text" || kind == "raw") {
        const auto content = value.fields(2);
        node.kind = kind == "text" ? NodeKind::text : NodeKind::raw;
        node.text = content[1].text();

        return node;
    }

    if (kind == "list") {
        const auto content = value.fields(2);
        const auto children = content[1].list();
        node.children.reserve(children.size());

        for (const auto& child : children) {
            node.children.push_back(decode_node(child));
        }

        return node;
    }

    if (kind != "element") {
        throw std::runtime_error(std::format("unknown node kind '{}'", kind));
    }

    const auto element = value.fields(6);
    node.kind = NodeKind::element;
    node.tag = element[1].text();
    node.declarations = element[3].text();

    const auto void_flag = element[4].text();

    if (void_flag != "0" && void_flag != "1") {
        throw std::runtime_error("invalid void-element flag");
    }

    node.is_void = void_flag == "1";

    const auto attributes = element[2].list();
    node.attributes.reserve(attributes.size());

    for (const auto& attribute : attributes) {
        node.attributes.push_back(decode_attribute(attribute));
    }

    node.children.push_back(decode_node(element[5]));
    return node;
}

[[nodiscard]] bool valid_output_path(std::string_view path) {
    constexpr std::string_view allowed =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-";

    if (path.empty()) {
        return false;
    }

    while (true) {
        const auto slash = path.find('/');
        const auto part = path.substr(0, slash);

        if (part.empty() || part == "." || part == ".." ||
            part.find_first_not_of(allowed) != std::string_view::npos) {
            return false;
        }

        if (slash == std::string_view::npos) {
            return true;
        }

        path.remove_prefix(slash + 1);
    }
}

} // namespace

std::vector<Page> parse_manifest(std::string_view source) {
    const auto manifest = Parser{source}.parse();
    const auto entries = manifest.list();
    std::vector<Page> pages;
    std::set<std::string_view> paths;
    pages.reserve(entries.size());

    for (const auto& entry : entries) {
        const auto fields = entry.fields(2);
        const auto path = fields[0].text();

        if (!valid_output_path(path)) {
            throw std::runtime_error(std::format("unsafe output path '{}'", path));
        }

        if (path == "_ionix" || path.starts_with("_ionix/") || !paths.insert(path).second) {
            throw std::runtime_error(std::format("reserved or duplicate output path '{}'", path));
        }

        pages.push_back(Page{
            .path = std::string{path},
            .root = decode_node(fields[1]),
        });
    }

    // check for file/directory collisions
    for (auto path : paths) {
        for (auto slash = path.find('/'); slash != std::string_view::npos;
             slash = path.find('/', slash + 1)) {
            if (paths.contains(path.substr(0, slash))) {
                throw std::runtime_error("output file/directory collision");
            }
        }
    }

    return pages;
}

} // namespace ionix
