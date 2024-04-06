let
  inherit
    (builtins.import ./gleam.nix)
      Ok
      Error
      isOk
      toList;

  Nil = null;

  # As a temporary workaround, our Dict type works in the following way:
  # 1. Simple key types are stored as strings in '_attrs', and access to them
  # is relatively fast, using Nix's built-in hashing.
  # 2. Complex key types are stored as { key = ..., value = ... } pairs in '_list',
  # with O(n) access.
  Dict = { __gleamTag = "Dict"; _attrs = {}; _list = []; };

  # "Hash" the key...
  generate_key =
    key:
      if builtins.isString key
      then Ok "S${key}"
      else if builtins.isInt key
      then Ok "I${builtins.toJSON key}"
      else if builtins.isNull key
      then Ok "N"
      else if builtins.isBool key
      then Ok "B${if key then "1" else "0"}"
      else if builtins.isPath key
      then Ok "P${builtins.toString key}"
      else if builtins.isAttrs key && key ? __gleamTag && builtins.attrNames key == [ "__gleamTag" ]
      then Ok "R${key.__gleamTag}" # record variant without fields, so it's simple enough to store here directly
      else Error key; # for floats, other attribute sets, and also lists, we store as key/value pairs in '_list'.

  new_map = {}: Dict;

  map_size =
    map:
      builtins.length (builtins.attrNames map._attrs)
        + builtins.length map._list;

  map_to_list =
    map:
      let
        makeAttrPair =
          k:
            let
              pair = map._attrs.${k};
            in [ pair.key pair.value ];
        attrPairs = builtins.map makeAttrPair (builtins.attrNames map._attrs);
        remainingPairs = builtins.map ({ key, value }: [ key value ]) map._list;
      in toList (attrPairs ++ remainingPairs);

  map_insert =
    key: value: map:
      let
        genKey = generate_key key;
        finalKey = genKey._0;
        newPair = { inherit key value; };
        updatedAttrs = map._attrs // { "${finalKey}" = newPair; };
        updatedList =
          if builtins.any (pair: pair.key == key) map._list
          then builtins.map (pair: if pair.key == key then newPair else pair) map._list
          else map._list ++ [ newPair ];
      in
        if isOk genKey
        then map // { _attrs = updatedAttrs; }
        else map // { _list = updatedList; };

  find_first_key_in_list =
    key:
      builtins.foldl'
        (acc: elem:
          if isOk acc
          then acc # keep the element we found
          else if elem.key == key
          then Ok elem.value
          else acc)
        (Error Nil);

  map_get =
    map: key:
      let
        genKey = generate_key key;
        finalKey = genKey._0;
      in
        if isOk genKey
        then
          if map._attrs ? ${finalKey}
          then Ok map._attrs.${finalKey}.value
          else Error Nil
        else find_first_key_in_list key map._list;

  map_remove =
    key: map:
      let
        genKey = generate_key key;
        finalKey = genKey._0;
        updatedAttrs = builtins.removeAttrs map._attrs [ finalKey ];
        updatedList = builtins.filter (pair: pair.key != key) map._list;
      in
        if isOk genKey
        then map // { _attrs = updatedAttrs; }
        else map // { _list = updatedList; };

  map_from_attrs =
    set:
      let
        names = builtins.attrNames set;
      in builtins.foldl' (map: name: map_insert name set.${name} map) (new_map {}) names;

in { inherit Dict new_map map_size map_get map_insert map_remove map_to_list map_from_attrs; }
