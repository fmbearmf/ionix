{
  pkgs ? import <nixpkgs> { },
  ionix ? import ../../lib { inherit (pkgs) lib; },
}:

let
  t = ionix.html.tags;
  inherit (ionix) ui;

  colors = {
    background = "#10151f";
    surface = "#1a2230";
    border = "#334155";
    text = "#e2e8f0";
    muted = "#a8b5c8";
    accent = "#93c5fd";
  };

  link =
    href: label:
    t.a {
      inherit href;
      styles = [
        {
          color = colors.accent;
          text-decoration = "none";
          font-weight = "600";
        }
      ];
    } label;

  card =
    title: description:
    t.article
      {
        styles = [
          ui.flex
          ui.column
          {
            background-color = colors.surface;
            border = "1px solid ${colors.border}";
            border-radius = "16px";
            padding = "1.5rem";
            gap = "0.75rem";
            line-height = "1.6";
          }
        ];
      }
      [
        (t.h2 {
          styles = [
            {
              margin = "0";
              font-size = "1.15rem";
            }
          ];
        } title)
        (t.p {
          styles = [
            {
              margin = "0";
              color = colors.muted;
            }
          ];
        } description)
      ];

  cards =
    children:
    t.div {
      styles = [
        ui.grid
        {
          grid-template-columns = "repeat(auto-fit, minmax(min(100%, 16rem), 1fr))";
          gap = "1rem";
        }
      ];
    } children;

  heading =
    eyebrow: title: description:
    t.header
      {
        styles = [
          {
            padding = "3rem 0";
            max-width = "44rem";
          }
        ];
      }
      [
        (t.p {
          styles = [
            ui.text.bold
            {
              color = colors.accent;
              letter-spacing = "0.1em";
            }
          ];
        } eyebrow)
        (t.h1 {
          styles = [
            {
              font-size = "clamp(2.25rem, 7vw, 4rem)";
              line-height = "1.1";
              margin = "1rem 0";
            }
          ];
        } title)
        (t.p {
          styles = [
            {
              color = colors.muted;
              font-size = "1.15rem";
              line-height = "1.7";
            }
          ];
        } description)
      ];
in
ionix.mkSite {
  inherit pkgs;

  name = "ionix-example-site";
  title = "Ionix";
  description = "better web dev";

  # this is the only handwritten CSS
  head = [ (t.style { } "body { margin: 0; }") ];

  layout =
    { content, page, ... }:
    t.div
      {
        styles = [
          {
            background-color = colors.background;
            color = colors.text;
            font-family = "system-ui, sans-serif";
            min-height = "100vh";
            padding = "0 clamp(1rem, 4vw, 3rem)";
          }
        ];
      }
      [
        (t.div
          {
            styles = [
              {
                max-width = "70rem";
                margin = "0 auto";
              }
            ];
          }
          [
            (t.nav
              {
                aria-label = "Main navigation";
                styles = [
                  ui.flex
                  ui.wrap
                  {
                    gap = "1.5rem";
                    padding = "1.5rem 0";
                  }
                ];
              }
              [
                (link "/" "Ionix / home")
              ]
            )
            (t.main { } content)
            (t.footer {
              styles = [
                {
                  color = colors.muted;
                  padding = "3rem 0 2rem";
                  line-height = "1.6";
                }
              ];
            } "${page.title} - Powered by hamsters.")
          ]
        )
      ];

  pages = [
    {
      route = "/";
      title = "Ionix";

      body = [
        (heading "New tech." "Hello, Vro." "Static pages have been blessed by John Nix and Rupert CSS.")
        (cards [
          (card "Oh, well" "Honor for all of the big and the small")
          (card "Well, the taller they stand" "Well, the harder they fall")
          (card "We live for today but we die for the next" "With blood in our veins and the air in our chest")
          (card "So we step into war with our hearts on the line" "The dirt on our boots, it shakes free over time")
        ])
      ];
    }
  ];
}
