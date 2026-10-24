{ ionix }:

let
  inherit (ionix) css html;

  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;

  rules = [
    (css.rule ".article > p" [
      (css.color (css.hex "#202122"))
      (css.margin (css.rem 1))
    ])

    (css.rule ".article a:hover" [ { text-decoration = "underline"; } ])

    (css.media { maxWidth = css.rem 48; } [
      (css.rule ".article" [ (css.important [ (css.padding (css.rem 1)) ]) ])
    ])

    (css.media { type = "print"; } [
      (css.rule ".sidebar" [ (css.display "none") ])
    ])
  ];

  expected =
    ".article > p{color:#202122;margin:1rem;}"
    + ".article a:hover{text-decoration:underline;}"
    + "@media all and (max-width: 48rem){.article{padding:1rem !important;}}"
    + "@media print{.sidebar{display:none;}}";

  sheet = html.stylesheet rules;
in

assert css.stylesheet rules == expected;
assert html.render sheet == "<style>${expected}</style>";
assert builtins.elem [ "raw" expected ] (html.toNative sheet);
assert css.stylesheet [ ] == "";

assert
  html.render (
    html.stylesheet [
      (css.rule ''a[title="Next"]::after'' [ { content = ''"→"''; } ])
    ]
  ) == ''<style>a[title="Next"]::after{content:"→";}</style>'';

assert
  css.stylesheet [
    (css.media
      {
        type = "screen";
        minWidth = css.px 0;
        orientation = "landscape";
      }
      [
        (css.media { reducedMotion = "reduce"; } [
          (css.rule "a" [ { transition = "none"; } ])
        ])
      ]
    )
  ]
  == "@media screen and (min-width: 0px) and (orientation: landscape){@media all and (prefers-reduced-motion: reduce){a{transition:none;}}}";

assert fails (css.rule "" [ ]);
assert fails (css.rule "   " [ ]);
assert fails (css.rule "a{}body" [ ]);
assert fails (css.rule "a;body" [ ]);
assert fails (css.rule "@import url(x)" [ ]);
assert fails (css.rule "a/*comment*/" [ ]);
assert fails (css.rule "</style><script>" [ ]);
assert fails (css.rule "a" [ { color = "red;display:none"; } ]);
assert fails (css.rule "a" [ { content = "</style>"; } ]);
assert fails (css.stylesheet [ ".article{}" ]);
assert fails (
  css.stylesheet [
    {
      _ionixCSSRule = {
        kind = "selector";
        selector = "</style>";
        styles = [ ];
      };
    }
  ]
);

assert fails (css.media { type = "screen;body"; } [ ]);
assert fails (css.media { maxWidth = "48rem"; } [ ]);
assert fails (css.media { maxWidth = css.hex "#fff"; } [ ]);
assert fails (css.media { maxWidth = css.percent 50; } [ ]);
assert fails (css.media { maxWidth = css.rem (-1); } [ ]);
assert fails (css.media { orientation = "sideways"; } [ ]);
assert fails (css.media { reducedMotion = true; } [ ]);
assert fails (css.media { typo = true; } [ ]);
assert fails (css.media { } [ "raw CSS" ]);

true
