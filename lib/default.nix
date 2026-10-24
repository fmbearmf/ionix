{ lib }:

let
  html = import ./html.nix { inherit lib; };
  ui = import ./ui.nix;
  cssEngine = pkgs: pkgs.callPackage ../native { };

  validPath =
    path:
    builtins.isString path
    && path != ""
    && lib.all (part: part != "." && part != ".." && builtins.match "[A-Za-z0-9_.-]+" part != null) (
      lib.splitString "/" path
    );

  routeToPath =
    route:
    if route == "/" then
      "index.html"
    else if !lib.hasPrefix "/" route then
      throw "Ionix: route must start with '/': ${route}"
    else
      let
        relative = lib.removePrefix "/" route;

        directory = lib.hasSuffix "/" relative;

        stem = if directory then lib.removeSuffix "/" relative else relative;
      in
      if !validPath stem || !(directory || lib.hasSuffix ".html" stem) then
        throw "Ionix: invalid route '${route}'; use '/', '/path/', or '/path.html'"
      else if directory then
        "${stem}/index.html"
      else
        stem;

  unique = values: builtins.length values == builtins.length (lib.unique values);
  xml = html.escape;
in
{
  inherit
    html
    ui
    routeToPath
    cssEngine
    ;

  mkSite =
    {
      pkgs,
      name ? "ionix-site",
      title,
      description ? "",
      url ? null,
      lang ? "en",
      pages,
      layout ? ({ content, ... }: content),
      head ? [ ],
      assets ? { },
      files ? { },
      sitemap ? url != null,
      robots ? url != null,
    }:
    let
      t = html.tags;

      site = {
        inherit
          title
          description
          url
          lang
          ;
      };

      routes = map (page: page.route) pages;

      pagePaths = map routeToPath routes;

      origin = if url == null then null else lib.removeSuffix "/" url;

      validOrigin = origin == null || builtins.match "https?://[A-Za-z0-9][A-Za-z0-9.:-]*" origin != null;

      renderPage =
        page:
        let
          context = {
            inherit
              html
              ui
              site
              page
              ;
          };

          content = if builtins.isFunction page.body then page.body context else page.body;

          pageTitle = if page.title == title then title else "${page.title} · ${title}";
          pageDescription = page.description or description;

          extraHead = page.head or [ ];
        in
        html.toNative (
          t.html { inherit lang; } [
            (t.head { } [
              (t.meta { charset = "utf-8"; } [ ])

              (t.meta {
                name = "viewport";
                content = "width=device-width, initial-scale=1";
              } [ ])

              (t.title { } pageTitle)

              (
                if pageDescription == "" then
                  null
                else
                  t.meta {
                    name = "description";
                    content = pageDescription;
                  } [ ]
              )

              (
                if origin == null then
                  null
                else
                  t.link {
                    rel = "canonical";
                    href = origin + page.route;
                  } [ ]
              )

              head
              extraHead
            ])

            (t.body { } (layout (context // { inherit content; })))
          ]
        );

      manifest = pkgs.writeText "ionix-pages" (
        html.encodeNative (
          map (page: [
            (routeToPath page.route)
            (renderPage page)
          ]) pages
        )
      );

      sitemapContent = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${
          lib.concatMapStrings (
            page:
            if !(page.sitemap or true) then
              ""
            else
              "<url><loc>${xml (origin + page.route)}</loc>"
              + (if page ? lastmod then "<lastmod>${xml page.lastmod}</lastmod>" else "")
              + "</url>"
          ) pages
        }</urlset>
      '';

      generated =
        lib.optionalAttrs sitemap { "sitemap.xml" = sitemapContent; }
        // lib.optionalAttrs robots {
          "robots.txt" =
            "User-agent: *\nAllow: /\n" + lib.optionalString sitemap "Sitemap: ${origin}/sitemap.xml\n";
        };

      allPaths =
        pagePaths
        ++ builtins.attrNames files
        ++ builtins.attrNames assets
        ++ lib.optional sitemap "sitemap.xml"
        ++ lib.optional robots "robots.txt";

      noPrefixes = lib.all (a: lib.all (b: !lib.hasPrefix "${a}/" b) allPaths) allPaths;
      textFiles = lib.mapAttrs (
        path: text:
        if !builtins.isString text then
          throw "Ionix: file '${path}' must contain a string"
        else
          pkgs.writeText "ionix-${builtins.substring 0 16 (builtins.hashString "sha256" path)}" text
      ) (generated // files);

      sources = textFiles // assets;
      install =
        path: input:
        let
          source = if builtins.isPath input then "${input}" else toString input;
        in
        ''
          mkdir -p -- "$out"/${lib.escapeShellArg (dirOf path)}
          if [ ! -f ${lib.escapeShellArg source} ]; then
            echo ${lib.escapeShellArg "Ionix: '${path}' must have a regular file source"} >&2
            exit 1
          fi
          cp -L -- ${lib.escapeShellArg source} "$out"/${lib.escapeShellArg path}
          chmod 444 -- "$out"/${lib.escapeShellArg path}
        '';

    in
    if !validOrigin then
      throw "Ionix: url must be an absolute HTTP(s) origin (no path, query, or fragment)"
    else if sitemap && origin == null then
      throw "Ionix: sitemap requires url"
    else if pages == [ ] then
      throw "Ionix: pages must not be empty"
    else if !unique routes || !unique allPaths then
      throw "Ionix: duplicate route or output path"
    else if !lib.all validPath allPaths then
      throw "Ionix: output paths must be safe relative paths"
    else if lib.any (path: path == "_ionix" || lib.hasPrefix "_ionix/" path) allPaths then
      throw "Ionix: '_ionix/' is reserved for generated assets"
    else if !noPrefixes then
      throw "Ionix: output file/directory collision"
    else
      pkgs.runCommand name
        {
          nativeBuildInputs = [ (cssEngine pkgs.buildPackages) ];
          preferLocalBuild = true;
          allowSubstitutes = false;

          passthru = {
            inherit routes;

            # content-addressed by the build step
            outputPaths = allPaths;
            cssAssetDirectory = "_ionix/css";
          };
        }
        ''
          mkdir -p "$out"
          ionix-css ${manifest} "$out"
          ${lib.concatStrings (lib.mapAttrsToList install sources)}

          find "$out" -exec touch -h -d @1 {} +
        '';
}
