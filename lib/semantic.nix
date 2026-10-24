{ lib }:

let
  fail = message: throw "Ionix semantic: ${message}";

  name = s: builtins.isString s && s != "";

  ref = id: if name id then { _ionixRef = id; } else fail "reference IDs must be non-empty strings";

  isRef =
    value:
    builtins.isAttrs value && builtins.attrNames value == [ "_ionixRef" ] && name value._ionixRef;

  values = value: if builtins.isList value then value else [ value ];

  kind =
    value:
    if isRef value then
      "ref"
    else if builtins.isString value then
      "text"
    else if builtins.isBool value then
      "boolean"
    else if builtins.isInt value || builtins.isFloat value then
      "number"
    else
      fail "facts must be text, numbers, booleans, references, or lists of these";

  kinds = [
    "text"
    "number"
    "boolean"
    "ref"
  ];

  jsonValue = value: if isRef value then { "@id" = value._ionixRef; } else value;
in
{
  inherit ref isRef;

  mkGraph =
    {
      entities,
      schema ? { },
    }:
    let
      checkSpec =
        spec:
        builtins.isAttrs spec
        && lib.all (
          key:
          builtins.elem key [
            "type"
            "required"
            "many"
            "target"
          ]
        ) (builtins.attrNames spec)
        && builtins.elem (spec.type or null) kinds
        && builtins.isBool (spec.required or false)
        && builtins.isBool (spec.many or false)
        && (
          !(spec ? target) || (spec.type == "ref" && name spec.target && builtins.hasAttr spec.target schema)
        );

      validSchema =
        builtins.isAttrs schema
        && lib.all (
          type:
          name type
          && builtins.isAttrs schema.${type}
          && lib.all (property: name property && checkSpec schema.${type}.${property}) (
            builtins.attrNames schema.${type}
          )
        ) (builtins.attrNames schema);

      checked = lib.mapAttrs (
        id: entity:
        let
          type = entity.type or null;

          properties = entity.properties or { };

          specs = schema.${type} or { };

          checkProperty =
            property: value:
            let
              spec = specs.${property} or null;

              xs = values value;
            in
            if !name property then
              fail "empty property on '${id}'"
            else if schema != { } && spec == null then
              fail "unknown property '${property}' on '${id}'"
            else if spec != null && (builtins.isList value != (spec.many or false)) then
              fail "cardinality mismatch for '${id}.${property}'"
            else if spec != null && (spec.required or false) && xs == [ ] then
              fail "required property '${id}.${property}' is empty"
            else
              map (
                v:
                let
                  k = kind v;
                in
                if spec != null && k != spec.type then
                  fail "wrong type for '${id}.${property}': expected ${spec.type}"
                else if k == "ref" && !(builtins.hasAttr v._ionixRef entities) then
                  fail "dangling reference '${v._ionixRef}' on '${id}'"
                else if
                  k == "ref" && spec != null && spec ? target && (entities.${v._ionixRef}.type or null) != spec.target
                then
                  fail "reference '${id}.${property}' must target '${spec.target}'"
                else
                  v
              ) xs;

          checkedProperties = lib.mapAttrs checkProperty properties;

          missing = lib.any (
            property: (specs.${property}.required or false) && !(builtins.hasAttr property properties)
          ) (builtins.attrNames specs);
        in
        if !name id || !builtins.isAttrs entity then
          fail "entities must be attribute sets with non-empty IDs"
        else if !name type || !builtins.isAttrs properties then
          fail "'${id}' requires a type and a properties set"
        else if schema != { } && !(builtins.hasAttr type schema) then
          fail "unknown type '${type}' on '${id}'"
        else if missing then
          fail "missing required property on '${id}'"
        else
          builtins.deepSeq checkedProperties { inherit id type properties; }
      ) entities;

      nodes = builtins.attrValues checked;

      get = id: checked.${id} or (fail "unknown entity '${id}'");

      triples = lib.concatMap (
        entity:
        lib.concatLists (
          lib.mapAttrsToList (
            property: value:
            map (object: {
              subject = entity.id;
              predicate = property;
              inherit object;
            }) (values value)
          ) entity.properties
        )
      ) nodes;
    in
    if !builtins.isAttrs entities then
      fail "entities must be an attribute set"
    else if !validSchema then
      fail "invalid schema (expected property specs with type, optional required/many/target)"
    else
      builtins.deepSeq checked {
        inherit get triples;

        entities = checked;

        query =
          {
            type ? null,
            where ? { },
          }:
          lib.filter (
            entity:
            (type == null || entity.type == type)
            && lib.all (
              property:
              builtins.hasAttr property entity.properties
              && builtins.elem where.${property} (values entity.properties.${property})
            ) (builtins.attrNames where)
          ) nodes;

        backlinks =
          id:
          builtins.seq (get id) (
            lib.filter (triple: isRef triple.object && triple.object._ionixRef == id) triples
          );

        toJSONLD = context: {
          "@context" = context;
          "@graph" = map (
            entity:
            {
              "@id" = entity.id;
              "@type" = entity.type;
            }
            // lib.mapAttrs (
              property: value:
              if
                builtins.elem property [
                  "@id"
                  "@type"
                  "@context"
                  "@graph"
                ]
              then
                fail "reserved JSON-LD property '${property}'"
              else if builtins.isList value then
                map jsonValue value
              else
                jsonValue value
            ) entity.properties
          ) nodes;
        };
      };
}
