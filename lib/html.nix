{ lib }:

let
  escape =
    value:
    builtins.replaceStrings [ "&" "<" ">" "\"" "'" ] [ "&amp;" "&lt;" "&gt;" "&quot;" "&#39;" ] value;

  validName = name: builtins.match "[a-zA-Z][a-zA-Z0-9:_-]*" name != null;

  voidTags = [
    "area"
    "base"
    "br"
    "col"
    "embed"
    "hr"
    "img"
    "input"
    "link"
    "meta"
    "param"
    "source"
    "track"
    "wbr"
  ];

  fragment = value: { _ionixHTML = value; };

  render =
    node:
    if node == null then
      ""
    else if builtins.isString node then
      escape node
    else if builtins.isInt node || builtins.isFloat node then
      toString node
    else if builtins.isList node then
      lib.concatMapStrings render node
    else if builtins.isAttrs node && node ? _ionixHTML && builtins.isString node._ionixHTML then
      node._ionixHTML
    else
      throw "Ionix HTML: children must be text, numbers, lists, null, or HTML nodes";

  attrs =
    attributes:
    lib.concatStrings (
      lib.mapAttrsToList (
        name: value:
        if !validName name then
          throw "Ionix HTML: invalid attribute name '${name}'"
        else if value == null || value == false then
          ""
        else if value == true then
          " ${name}"
        else if builtins.isString value || builtins.isInt value || builtins.isFloat value then
          " ${name}=\"${escape (toString value)}\""
        else
          throw "Ionix HTML: invalid value for attribute '${name}'"
      ) attributes
    );

  el =
    tag: attributes: children:
    if !validName tag then
      throw "Ionix HTML: invalid tag '${tag}'"
    else if builtins.elem tag voidTags then
      if render children != "" then
        throw "Ionix HTML: void element '${tag}' cannot have children"
      else
        fragment "<${tag}${attrs attributes}>"
    else
      fragment "<${tag}${attrs attributes}>${render children}</${tag}>";
in
{
  inherit escape render el;

  # the escape hatch...
  raw = fragment;

  tags = lib.genAttrs [
    "a"
    "abbr"
    "address"
    "article"
    "aside"
    "audio"
    "b"
    "blockquote"
    "body"
    "br"
    "button"
    "caption"
    "code"
    "col"
    "colgroup"
    "dd"
    "del"
    "details"
    "dfn"
    "dialog"
    "div"
    "dl"
    "dt"
    "em"
    "fieldset"
    "figcaption"
    "figure"
    "footer"
    "form"
    "h1"
    "h2"
    "h3"
    "h4"
    "h5"
    "h6"
    "head"
    "header"
    "hr"
    "html"
    "i"
    "iframe"
    "img"
    "input"
    "kbd"
    "label"
    "legend"
    "li"
    "link"
    "main"
    "mark"
    "meta"
    "nav"
    "noscript"
    "ol"
    "option"
    "p"
    "picture"
    "pre"
    "progress"
    "q"
    "s"
    "samp"
    "script"
    "section"
    "select"
    "small"
    "source"
    "span"
    "strong"
    "style"
    "sub"
    "summary"
    "sup"
    "table"
    "tbody"
    "td"
    "textarea"
    "th"
    "thead"
    "time"
    "title"
    "tr"
    "ul"
    "video"
    "wbr"
  ] el;
}
