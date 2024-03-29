let
  inherit (builtins.import ./gleam.nix) Ok Error toList bitArrayByteSize toBitArray isOk listIsEmpty;
  inherit (builtins.import ./gleam/dynamic.nix) DecodeError;

  Nil = null;

  identity = x: x;

  unimplemented0 = throw "Unimplemented";
  unimplemented = _: throw "Unimplemented";
  unimplemented2 = _: _: throw "Unimplemented";
  unimplemented3 = _: _: _: throw "Unimplemented";
  unimplemented4 = _: _: _: _: throw "Unimplemented";

  parse_int =
    let
      int_without_leading_zero_match = builtins.match "^([-+]?)0*([[:digit:]]+)$";
    in
      v:
        let
          matched_int = int_without_leading_zero_match v;
          int_sign = if matched_int != null then builtins.head matched_int else null;
          int_digits = if matched_int != null then builtins.elemAt matched_int 1 else null;

          # Plus sign isn't supported by JSON
          minus_sign = if int_sign == "+" then "" else int_sign;
        in if matched_int == null then Error Nil else Ok (builtins.fromJSON (minus_sign + int_digits));

  bitwise_and = builtins.bitAnd;

  bitwise_not = builtins.bitXor (-1);

  bitwise_or = builtins.bitOr;

  bitwise_exclusive_or = builtins.bitXor;

  parse_float =
    let
      float_without_leading_zero_match = builtins.match "^([-+]?)0*([[:digit:]]+)\\.([[:digit:]]+)$";
    in
      v:
        let
          matched_float = float_without_leading_zero_match v;
          float_sign = if matched_float != null then builtins.head matched_float else null;
          float_digits = if matched_float != null then builtins.elemAt matched_float 1 else null;
          float_extra_digits = if matched_float != null then builtins.elemAt matched_float 2 else null;

          # Plus sign isn't supported by JSON
          minus_sign = if float_sign == "+" then "" else float_sign;
        in if matched_float == null then Error Nil else Ok (builtins.fromJSON (minus_sign + float_digits + "." + float_extra_digits));

  to_string = builtins.toString;

  float_to_string = builtins.toJSON;

  # Taken from nixpkgs.lib.strings
  essentials = rec {
    stringToCharacters =
      s:
        builtins.genList (p: builtins.substring p 1 s) (builtins.stringLength s);

    addContextFrom = a: b: builtins.substring 0 0 a + b;

    escape = list: builtins.replaceStrings list (map (c: "\\${c}") list);

    escapeRegex = escape (stringToCharacters "\\[{()^$?*+|.");

    splitString =
      sep: s:
        let
          splits = builtins.filter builtins.isString (builtins.split (escapeRegex (toString sep)) (toString s));
        in
          map (addContextFrom s) splits;

    lowerChars = stringToCharacters "abcdefghijklmnopqrstuvwxyz";

    upperChars = stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    toLower = builtins.replaceStrings upperChars lowerChars;

    toUpper = builtins.replaceStrings lowerChars upperChars;

    hasPrefix =
      pref: str:
        builtins.substring 0 (builtins.stringLength pref) str == pref;

    hasSuffix =
      suffix: content:
        let
          lenContent = builtins.stringLength content;
          lenSuffix = builtins.stringLength suffix;
        in
          lenContent >= lenSuffix && builtins.substring (lenContent - lenSuffix) lenContent content == suffix;

    hasInfix =
      infix: content:
        builtins.match ".*${escapeRegex infix}.*" "${content}" != null;
  };

  ceiling = builtins.ceil;

  floor = builtins.floor;

  round = f:
    let
      int = div' f 1;
      inc = if mod' f 1 >= 0.5 then 1 else 0;
    in int + inc;

  truncate = f: div' f 1;

  to_float = i: 1.0 * i;

  div' = n: d:
    floor (builtins.div n d);

  mod' = n: d:
    let
      f = div' n d;
    in n - f * d;

  classify_dynamic = d:
    if builtins.isInt d then "Int"
    else if builtins.isFloat d then "Float"
    else if builtins.isBool d then "Bool"
    else if builtins.isFunction d then "Function"
    else if builtins.isNull d then "Nil"
    else if builtins.isString d then "String"
    else "Some other type";

  decoder_error =
    expected: got:
      decoder_error_no_classify expected (classify_dynamic got);

  decoder_error_no_classify =
    expected: got:
      Error (toList [DecodeError expected got (toList [])]);

  decode_string = data: if builtins.isString data then Ok data else decoder_error "String" data;

  decode_int = data: if builtins.isInt data then Ok data else decoder_error "Int" data;

  decode_float = data: if builtins.isFloat data then Ok data else decoder_error "Float" data;

  decode_bool = data: if builtins.isBool data then Ok data else decoder_error "Bool" data;

  decode_result =
    data:
      if
        builtins.isAttrs data &&
        data ? __gleamTag &&
        (
          data.__gleamTag == "Ok" ||
          data.__gleamTag == "Error"
        ) &&
        data ? _0
      then if isOk data then Ok (Ok data._0) else Ok (Error data._0)
      else decoder_error "Result" data;

  inspect =
    data:
      if builtins.isInt data || builtins.isFloat data
      then builtins.toString data
      else if data == true then "True"
      else if data == false then "False"
      else if builtins.isNull data then "Nil"
      else if builtins.isString data then builtins.toJSON data
      else if builtins.isFunction data then "//fn(...) { ... }"
      else if builtins.isList data then
        let
          inspected_list = map inspect data;
          joined_inspected_list = builtins.concatStringsSep ", " inspected_list;
        in "#(${joined_inspected_list})"
      else if builtins.isPath data then "//nix(${builtins.toString data})"
      else if builtins.isAttrs data then
        let
          attr_mapper =
            a:
              " ${a} = ${inspect data.${a}};";

          attr_pairs = builtins.concatStringsSep "" (map attr_mapper (builtins.attrNames data));
        in "//nix({${attr_pairs} })"
      else "//nix(...)";  # TODO: Detect built-in data types, possibly others.

  print = message: builtins.trace message null;

  add = a: b: a + b;

  concat = l: if l.__gleamTag == "Empty" then "" else l.head + concat l.tail;

  length = builtins.stringLength;

  lowercase = essentials.toLower;

  uppercase = essentials.toUpper;

  split = string: pattern: essentials.splitString pattern string;

  string_replace = string: pattern: substitute: builtins.replaceStrings [pattern] [substitute] string;

  less_than = a: b: a < b;

  contains_string = haystack: needle: essentials.hasInfix needle haystack;

  starts_with = haystack: needle: essentials.hasPrefix needle haystack;

  ends_with = haystack: needle: essentials.hasSuffix needle haystack;

  byte_size = bitArrayByteSize;

  list_to_mapped_nix_list = f: l: if listIsEmpty l then [] else [ (f l.head) ] ++ list_to_mapped_nix_list f l.tail;

  bit_array_concat = arrays: toBitArray (list_to_mapped_nix_list (a: a.buffer) arrays);

  bit_array_inspect = array: "<<${builtins.concatStringsSep ", " (map builtins.toString array.buffer)}>>";
in
  {
    inherit
      identity
      unimplemented0
      unimplemented
      unimplemented2
      unimplemented3
      unimplemented4
      parse_int
      bitwise_and
      bitwise_not
      bitwise_or
      bitwise_exclusive_or
      parse_float
      to_string
      float_to_string
      ceiling
      floor
      round
      truncate
      to_float
      classify_dynamic
      decode_string
      decode_int
      decode_float
      decode_bool
      decode_result
      inspect
      print
      add
      concat
      length
      lowercase
      uppercase
      split
      string_replace
      less_than
      contains_string
      starts_with
      ends_with
      byte_size
      bit_array_concat
      bit_array_inspect;
  }
