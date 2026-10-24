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

  # A deliberately small declaration language: literal CSS properties/values,
  # no selectors or rules. Later sets override earlier sets per property.
  declarations =
    styles:
    if !builtins.isList styles || !lib.all builtins.isAttrs styles then
      throw "Ionix CSS: styles must be a list of declaration sets"
    else
      lib.concatStrings (
        lib.mapAttrsToList (
          property: value:
          if builtins.match "(--[A-Za-z0-9_-]+|[a-z][a-z0-9-]*)" property == null then
            throw "Ionix CSS: invalid property '${property}'"
          else if !(builtins.isString value || builtins.isInt value || builtins.isFloat value) then
            throw "Ionix CSS: '${property}' must have a string or numeric value"
          else if toString value == "" || builtins.match ".*[;{}<>\n\r].*" (toString value) != null then
            throw "Ionix CSS: invalid value for '${property}'"
          else
            "${property}:${toString value};"
        ) (lib.foldl' (a: b: a // b) { } styles)
      );

  styledAttrs =
    attributes:
    let
      css = declarations (attributes.styles or [ ]);
      plain = removeAttrs attributes [ "styles" ];
      existing = plain.style or null;
    in
    if css == "" then
      plain
    else if existing != null && existing != false && !builtins.isString existing then
      throw "Ionix CSS: style must be a string when styles are present"
    else
      plain // { style = css + (if builtins.isString existing then existing else ""); };

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
    else if builtins.isAttrs node && node ? _ionixNode then
      let
        n = node._ionixNode;
      in
      "<${n.tag}${attrs (styledAttrs n.attributes)}>"
      + (if builtins.elem n.tag voidTags then "" else "${render n.children}</${n.tag}>")
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
    else if builtins.elem tag voidTags && render children != "" then
      throw "Ionix HTML: void element '${tag}' cannot have children"
    else
      { _ionixNode = { inherit tag attributes children; }; };

  wire =
    value:
    if builtins.isList value then
      "[${lib.concatMapStrings wire value}]"
    else
      "${toString (builtins.stringLength value)}:${value}";

  tree =
    node:
    if node == null then
      [
        "text"
        ""
      ]
    else if builtins.isString node || builtins.isInt node || builtins.isFloat node then
      [
        "text"
        (toString node)
      ]
    else if builtins.isList node then
      [
        "list"
        (map tree node)
      ]
    else if builtins.isAttrs node && node ? _ionixNode then
      let
        n = node._ionixNode;

        plain = removeAttrs n.attributes [ "styles" ];
        css = declarations (n.attributes.styles or [ ]);

        checked = attrs (styledAttrs n.attributes);
      in
      builtins.seq checked [
        "element"
        n.tag
        (lib.filter (a: a != [ ]) (
          lib.mapAttrsToList (
            name: value:
            if value == null || value == false then
              [ ]
            else if value == true then
              [ name ]
            else
              [
                name
                (toString value)
              ]
          ) plain
        ))
        css
        (if builtins.elem n.tag voidTags then "1" else "0")
        (tree n.children)
      ]
    else if builtins.isAttrs node && node ? _ionixHTML && builtins.isString node._ionixHTML then
      [
        "raw"
        node._ionixHTML
      ]
    else
      throw "Ionix HTML: invalid child";

in
{
  inherit escape render el;
  toNative = tree;
  encodeNative = wire;

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
