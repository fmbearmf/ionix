{ lib, ionix }:

let
  skin = import ../examples/wiki/styles.nix { inherit lib ionix; };
  site = import ../examples/wiki {
    pkgs = { inherit lib; };
    ionix = ionix // {
      mkSite = site: site;
    };
  };

  check =
    node:
    if builtins.isList node then
      lib.all check node
    else if builtins.isAttrs node && node ? _ionixNode then
      let
        n = node._ionixNode;
      in
      !(n.attributes ? class)
      && !(n.attributes ? style)
      && builtins.isString (ionix.css.declarations (n.attributes.styles or [ ]))
      && check n.children
    else
      true;

  stylesheet = ionix.html.render skin.head;
in

assert lib.all (
  page:
  check (
    site.layout {
      inherit page;
      content = page.body;
    }
  )
) site.pages;

assert lib.hasInfix "@media all and (max-width: 48rem)" stylesheet;
assert lib.hasInfix "@media print" stylesheet;
assert lib.hasInfix "--wiki-wiki-shell-display:block;" stylesheet;
assert lib.hasInfix "var(--wiki-wiki-shell-display, grid)" (
  ionix.css.declarations skin.styles.wiki-shell
);

assert
  ionix.css.merge (
    (skin.tags.p { styles = [ { margin = 0; } ]; } "test")._ionixNode.attributes.styles
  ) == {
    box-sizing = "border-box";
    margin = 0;
  };

true
