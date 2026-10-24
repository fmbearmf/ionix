{ lib }:

let
  ionix = import ../lib { inherit lib; };

  inherit (ionix) css html semantic;

  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;

  graph = semantic.mkGraph {
    schema = {
      Person = {
        name = {
          type = "text";
          required = true;
        };
        knows = {
          type = "ref";
          many = true;
          target = "Person";
        };
        age = {
          type = "number";
        };
        active = {
          type = "boolean";
        };
      };
    };
    entities = {
      ada = {
        type = "Person";
        properties = {
          name = "Ada";
          knows = [ (semantic.ref "grace") ];
          age = 36;
          active = true;
        };
      };
      grace = {
        type = "Person";
        properties.name = "Grace";
      };
    };
  };

  badGraph =
    properties:
    semantic.mkGraph {
      schema.Person = {
        name = {
          type = "text";
          required = true;
        };
        knows = {
          type = "ref";
          many = true;
        };
      };
      entities.ada = {
        type = "Person";
        inherit properties;
      };
    };

  styles = [
    ionix.ui.flex
    (css.padding [
      (css.rem 1)
      (css.px 8)
    ])
    (css.color (css.hex "#abc"))
    { width = css.percent 100; }
    (css.gap (css.rem 1))
    (css.gap (css.px 4))
  ];

  node = html.tags.div { inherit styles; } "hello";

  serialized = "color:#abc;display:flex;gap:4px;padding:1rem 8px;width:100%;";
in

assert import ./css-rules.nix { inherit ionix; };
assert import ./wiki.nix { inherit lib ionix; };

assert css.declarations styles == serialized;
assert html.render node == "<div style=\"${serialized}\">hello</div>";
assert builtins.elem serialized (html.toNative node);
assert
  css.declarations [
    (css.columns [
      (css.fr 1)
      (css.px 200)
    ])
  ] == "grid-template-columns:1fr 200px;";
assert
  css.declarations [ (css.fontSize (css.clamp (css.rem 1) (css.vw 4) (css.rem 3))) ]
  == "font-size:clamp(1rem, 4vw, 3rem);";
assert
  css.declarations [
    (css.custom "--accent" (css.hex "#abc"))
    (css.color (css.var "--accent"))
  ] == "--accent:#abc;color:var(--accent);";
assert
  css.merge [
    { color = "red"; }
    { color = "blue"; }
  ] == {
    color = "blue";
  };
assert
  css.declarations [
    (css.border {
      width = css.px 1;
      color = css.colors.black;
    })
  ] == "border-color:black;border-style:solid;border-width:1px;";

assert fails (css.px "12");
assert fails (css.padding (css.hex "#fff"));
assert fails (css.color (css.px 1));
assert fails (css.color 0);
assert fails (css.opacity 2);
assert fails (css.rgb 256 0 0);
assert fails (css.hex "red");
assert fails (css.display "fleex");
assert fails (css.padding [ ]);
assert fails (css.columns [ (css.hex "#fff") ]);
assert fails (css.declarations [ { color = "red;display:none"; } ]);
assert fails (css.declarations [ { "bad property" = "red"; } ]);
assert fails (css.declarations [ { color = true; } ]);
assert fails (html.toNative (html.tags.div { styles = [ { width = css.px "bad"; } ]; } [ ]));

assert (graph.get "ada").properties.name == "Ada";
assert map (entity: entity.id) (graph.query { where.knows = semantic.ref "grace"; }) == [ "ada" ];
assert builtins.length (graph.query { type = "Person"; }) == 2;
assert graph.query { where.active = false; } == [ ];
assert
  graph.backlinks "grace" == [
    {
      subject = "ada";
      predicate = "knows";
      object = semantic.ref "grace";
    }
  ];
assert builtins.length graph.triples == 5;
assert
  (builtins.head (graph.toJSONLD { "@vocab" = "https://example.org/"; })."@graph").knows
  == [ { "@id" = "grace"; } ];

assert fails (graph.get "missing");
assert fails (graph.backlinks "missing");
assert fails (badGraph { });
assert fails (badGraph {
  name = 42;
});
assert fails (badGraph {
  name = "Ada";
  unknown = "value";
});
assert fails (badGraph {
  name = "Ada";
  knows = semantic.ref "ada";
});
assert fails (badGraph {
  name = "Ada";
  knows = [ (semantic.ref "missing") ];
});
assert fails (
  semantic.mkGraph {
    entities.x = {
      type = "Thing";
      properties.value = null;
    };
  }
);
assert fails (
  semantic.mkGraph {
    schema.Thing.value.type = "typo";
    entities = { };
  }
);
assert fails (
  semantic.mkGraph {
    schema = {
      A.link = {
        type = "ref";
        target = "B";
      };
      B = { };
    };
    entities.x = {
      type = "A";
      properties.link = semantic.ref "x";
    };
  }
);

assert
  builtins.length (
    (semantic.mkGraph {
      entities.x = {
        type = "Thing";
        properties.self = semantic.ref "x";
      };
    }).backlinks
      "x"
  ) == 1;

true
