#pragma once

#include <optional>
#include <string>
#include <vector>

namespace ionix {

enum class NodeKind {
    text,
    raw,
    fragment,
    element,
};

struct Attribute {
    std::string name;

    // a missing value indicates a boolean attribute
    std::optional<std::string> value;
};

struct Node {
    NodeKind kind = NodeKind::fragment;
    std::string tag;
    std::string text;
    std::string declarations;
    bool is_void = false;
    std::vector<Attribute> attributes;
    std::vector<Node> children;
};

struct Page {
    std::string path;
    Node root;
};

} // namespace ionix
