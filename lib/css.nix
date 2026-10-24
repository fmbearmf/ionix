{ lib }:

let
  fail = message: throw "Ionix CSS: ${message}";

  number = n: builtins.isInt n || builtins.isFloat n;

  safe = s: builtins.isString s && s != "" && builtins.match ".*[;{}<>\n\r].*" s == null;

  typed = kind: value: { _ionixCSS = { inherit kind value; }; };

  isValue = v: builtins.isAttrs v && v ? _ionixCSS;

  render =
    v:
    let
      value =
        if isValue v then
          v._ionixCSS.value
        else if number v then
          toString v
        else
          v;
    in
    if safe value then value else fail "expected a non-empty CSS value without declaration delimiters";

  unit =
    suffix: n:
    if number n then typed "length" "${toString n}${suffix}" else fail "${suffix} expects a number";

  expect =
    kinds: v:
    if isValue v && builtins.elem v._ionixCSS.kind kinds then
      render v
    else if builtins.elem "length" kinds && number v && v == 0 then
      "0"
    else
      fail "expected a typed ${lib.concatStringsSep "/" kinds} value (or zero)";

  length = expect [
    "length"
    "variable"
  ];

  axis = a: b: value: {
    ${a} = length value;
    ${b} = length value;
  };

  lengthFunction = fn: args: typed "length" "${fn}(${lib.concatMapStringsSep ", " length args})";

  color = expect [
    "color"
    "variable"
  ];

  enum =
    property: choices: value:
    if builtins.isString value && builtins.elem value choices then
      { ${property} = value; }
    else
      fail "${property} expects one of: ${lib.concatStringsSep ", " choices}";

  space =
    property: values:
    let
      xs = if builtins.isList values then values else [ values ];
    in
    if xs == [ ] || builtins.length xs > 4 then
      fail "${property} expects 1–4 lengths"
    else
      { ${property} = lib.concatMapStringsSep " " length xs; };

  size =
    property: value:
    if
      builtins.isString value
      && builtins.elem value [
        "auto"
        "min-content"
        "max-content"
        "fit-content"
      ]
    then
      { ${property} = value; }
    else
      { ${property} = length value; };

  nonnegative =
    property: n:
    if number n && n >= 0 then
      { ${property} = n; }
    else
      fail "${property} expects a non-negative number";

  declarations =
    styles:
    if !builtins.isList styles || !lib.all builtins.isAttrs styles then
      fail "styles must be a list of declaration sets"
    else
      lib.concatStrings (
        lib.mapAttrsToList (
          property: value:
          if builtins.match "(--[A-Za-z0-9_-]+|[a-z][a-z0-9-]*)" property == null then
            fail "invalid property '${property}'"
          else
            "${property}:${render value};"
        ) (lib.foldl' (a: b: a // b) { } styles)
      );

  rule =
    selector: styles:
    if
      !builtins.isString selector
      || builtins.match "[ \t]*" selector != null
      || builtins.match ".*[@;{}<\n\r].*" selector != null
      || lib.hasInfix "/*" selector
      || lib.hasInfix "*/" selector
    then
      fail "expected a selector without at-rules, comments, or rule delimiters"
    else
      builtins.seq (declarations styles) {
        _ionixCSSRule = {
          kind = "selector";
          inherit selector styles;
        };
      };

  mediaQuery =
    query:
    if
      !builtins.isAttrs query
      || lib.any (
        key:
        !(builtins.elem key [
          "type"
          "minWidth"
          "maxWidth"
          "orientation"
          "reducedMotion"
        ])
      ) (builtins.attrNames query)
    then
      fail "media queries accept only type, minWidth, maxWidth, orientation, and reducedMotion"
    else
      mediaQueryUnchecked query;

  mediaQueryUnchecked =
    {
      type ? "all",
      minWidth ? null,
      maxWidth ? null,
      orientation ? null,
      reducedMotion ? null,
    }:
    let
      width =
        value:
        let
          text = length value;
        in
        if builtins.match "[0-9]+(\\.[0-9]+)?(px|rem|em)" text != null || text == "0" then
          text
        else
          fail "media widths must be non-negative px, rem, em, or zero";

      choice =
        label: choices: value:
        if builtins.elem value choices then value else fail "invalid media ${label}";

      features =
        lib.optional (minWidth != null) "(min-width: ${width minWidth})"
        ++ lib.optional (maxWidth != null) "(max-width: ${width maxWidth})"
        ++
          lib.optional (orientation != null)
            "(orientation: ${choice "orientation" [ "portrait" "landscape" ] orientation})"
        ++
          lib.optional (reducedMotion != null)
            "(prefers-reduced-motion: ${choice "reducedMotion" [ "reduce" "no-preference" ] reducedMotion})";

      medium = choice "type" [ "all" "screen" "print" ] type;
    in
    lib.concatStringsSep " and " ([ medium ] ++ features);

  stylesheet =
    rules:
    if !builtins.isList rules then
      fail "stylesheet expects a list of rules"
    else
      lib.concatMapStrings (
        node:
        if !builtins.isAttrs node || !(node ? _ionixCSSRule) then
          fail "expected a CSS rule or media query"
        else
          let
            r = node._ionixCSSRule;
          in
          if r.kind == "selector" then
            # Recheck the constructor invariants even for manually assembled nodes.
            builtins.seq (rule r.selector r.styles) "${r.selector}{${declarations r.styles}}"
          else if r.kind == "media" then
            "@media ${mediaQuery r.query}{${stylesheet r.rules}}"
          else
            fail "unknown stylesheet rule kind"
      ) rules;
in
{
  inherit
    render
    declarations
    rule
    stylesheet
    ;

  media =
    query: rules:
    builtins.seq (mediaQuery query) (
      builtins.seq (stylesheet rules) {
        _ionixCSSRule = {
          kind = "media";
          inherit query rules;
        };
      }
    );

  important =
    styles:
    builtins.seq (declarations styles) (
      lib.mapAttrs (_: value: "${render value} !important") (lib.foldl' (a: b: a // b) { } styles)
    );

  # escape hatch...
  css = attrs: builtins.seq (declarations [ attrs ]) attrs;

  merge = styles: builtins.seq (declarations styles) (lib.foldl' (a: b: a // b) { } styles);

  px = unit "px";
  rem = unit "rem";
  em = unit "em";
  percent = unit "%";
  vw = unit "vw";
  vh = unit "vh";

  fr =
    n:
    if number n && n > 0 then typed "track" "${toString n}fr" else fail "fr expects a positive number";

  # very many colors! thank you mr. light!
  hex =
    value:
    if
      builtins.isString value
      && builtins.match "#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})" value != null
    then
      typed "color" value
    else
      fail "hex expects #RGB, #RGBA, #RRGGBB, or #RRGGBBAA";

  rgb =
    r: g: b:
    if
      lib.all (n: builtins.isInt n && n >= 0 && n <= 255) [
        r
        g
        b
      ]
    then
      typed "color" "rgb(${toString r}, ${toString g}, ${toString b})"
    else
      fail "rgb channels must be integers between 0 and 255";

  colors = lib.genAttrs [
    "transparent"
    "currentColor"
    "black"
    "white"
    "red"
    "blue"
    "green"
  ] (typed "color");

  # Custom properties and length expressions.
  var =
    name:
    if builtins.isString name && builtins.match "--[A-Za-z0-9_-]+" name != null then
      typed "variable" "var(${name})"
    else
      fail "variable names must start with --";

  custom =
    name: value:
    if builtins.isString name && builtins.match "--[A-Za-z0-9_-]+" name != null then
      { ${name} = render value; }
    else
      fail "variable names must start with --";

  min =
    a: b:
    lengthFunction "min" [
      a
      b
    ];

  max =
    a: b:
    lengthFunction "max" [
      a
      b
    ];

  clamp =
    low: preferred: high:
    lengthFunction "clamp" [
      low
      preferred
      high
    ];

  # Spacing and sizing declarations.
  margin = space "margin";
  marginX = axis "margin-left" "margin-right";
  marginY = axis "margin-top" "margin-bottom";
  padding = space "padding";
  paddingX = axis "padding-left" "padding-right";
  paddingY = axis "padding-top" "padding-bottom";
  gap = value: { gap = length value; };

  width = size "width";
  height = size "height";
  minWidth = size "min-width";
  maxWidth = size "max-width";
  minHeight = size "min-height";
  maxHeight = size "max-height";

  # Color, typography, and decoration declarations.
  color = value: { color = color value; };
  background = value: { background-color = color value; };
  fontSize = value: { font-size = length value; };

  fontWeight =
    weight:
    if builtins.isInt weight && weight >= 1 && weight <= 1000 then
      { font-weight = weight; }
    else
      enum "font-weight" [ "normal" "bold" "bolder" "lighter" ] weight;

  lineHeight = n: nonnegative "line-height" n;

  opacity =
    n:
    if number n && n >= 0 && n <= 1 then
      { opacity = n; }
    else
      fail "opacity expects a number between 0 and 1";

  radius = value: { border-radius = length value; };

  border =
    {
      width,
      style ? "solid",
      color ? null,
    }:
    if color == null then
      fail "border requires a typed color"
    else
      {
        border-width = length width;
        border-style =
          (enum "border-style" [ "none" "solid" "dashed" "dotted" "double" ] style).border-style;
        border-color = expect [ "color" "variable" ] color;
      };

  # Layout keywords are enumerated to catch typos at evaluation time.
  display = enum "display" [
    "none"
    "block"
    "inline"
    "inline-block"
    "flex"
    "inline-flex"
    "grid"
    "inline-grid"
    "contents"
  ];

  position = enum "position" [
    "static"
    "relative"
    "absolute"
    "fixed"
    "sticky"
  ];

  direction = enum "flex-direction" [
    "row"
    "row-reverse"
    "column"
    "column-reverse"
  ];

  wrap = enum "flex-wrap" [
    "nowrap"
    "wrap"
    "wrap-reverse"
  ];

  align = enum "align-items" [
    "normal"
    "stretch"
    "start"
    "end"
    "center"
    "baseline"
  ];

  justify = enum "justify-content" [
    "normal"
    "start"
    "end"
    "center"
    "space-between"
    "space-around"
    "space-evenly"
  ];

  textAlign = enum "text-align" [
    "start"
    "end"
    "left"
    "right"
    "center"
    "justify"
  ];

  grow = nonnegative "flex-grow";
  shrink = nonnegative "flex-shrink";

  columns =
    tracks:
    if !builtins.isList tracks || tracks == [ ] then
      fail "columns expects a non-empty list of tracks"
    else
      {
        grid-template-columns = lib.concatMapStringsSep " " (expect [
          "length"
          "track"
          "variable"
        ]) tracks;
      };
}
