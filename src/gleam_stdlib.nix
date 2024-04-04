let
  inherit
    (builtins.import ./gleam.nix)
      Ok
      Error
      UtfCodepoint
      toList
      prepend
      byteSize
      toBitArray
      isOk
      listIsEmpty;

  inherit (builtins.import ./gleam/dynamic.nix) DecodeError;

  inherit (builtins.import ./gleam/option.nix) Some None;

  inherit (builtins.import ./gleam/regex.nix) Match;

  inherit (builtins.import ./dict.nix)
    new_map
    map_size
    map_get
    map_insert
    map_remove
    map_to_list;

  Nil = null;

  identity = x: x;

  unimplemented0 = {}: throw "Unimplemented";
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

  ascii_char_at = n: s: builtins.substring n 1 s;

  base_string = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

  # Maps indices to letters.
  base_map = essentials.stringToCharacters base_string;

  # Maps letters to indices.
  base_reverse_map = builtins.listToAttrs
    (builtins.genList
      (i: { name = builtins.elemAt base_map i; value = i; } )
      (builtins.length base_map));

  # Assumes the base is between 2 and 36, inclusive.
  int_from_base_string = string: base:
    let
      num_to_base_char = n: builtins.elemAt base_map n;
      max_valid_digit = if base > 10 then 9 else base - 1;
      max_valid_letter = if base > 10 then num_to_base_char (base - 1) else null;
      digit_pattern = "0-${builtins.toString max_valid_digit}";
      letter_pattern =
        if base == 11
        then "A"
        else if max_valid_letter != null
        then "A-${max_valid_letter}"
        else "";
      sign_factor = if ascii_char_at 0 string == "-" then -1 else 1;
      valid_base_num_match = builtins.match "^[-+]?([${digit_pattern}${letter_pattern}]+)$";
      matched_upper_string = valid_base_num_match (uppercase string);
      upper_string_without_sign = builtins.head matched_upper_string;
      initial_last_char = builtins.stringLength upper_string_without_sign - 1;
    in
      if string == "" || matched_upper_string == null
      then Error Nil
      else
        Ok
          (sign_factor *
            do_int_from_base_string upper_string_without_sign base initial_last_char);

  do_int_from_base_string = string: base: last_char_pos:
    let
      last_char = ascii_char_at last_char_pos string;
      converted_first_chars =
        if last_char_pos <= 0
        then 0
        else do_int_from_base_string string base (last_char_pos - 1);
      converted_last_char = base_reverse_map.${last_char};
    in base * converted_first_chars + converted_last_char;

  int_to_base_string = value: base:
    if value < 0
    then "-${int_to_base_string (-value) base}"
    else
      let
        last_digit = mod' value base;
        first_digits = value / base;
        converted_last_digit = builtins.elemAt base_map last_digit;
        converted_first_digits =
          if value < base
          then ""
          else int_to_base_string first_digits base;
      in converted_first_digits + converted_last_digit;

  bitwise_and = builtins.bitAnd;

  bitwise_not = builtins.bitXor (-1);

  bitwise_or = builtins.bitOr;

  bitwise_exclusive_or = builtins.bitXor;

  bitwise_shift_left = x: n: if n <= 0 then x else bitwise_shift_left (x * 2) (n - 1);

  bitwise_shift_right = x: n: if n <= 0 then x else bitwise_shift_right (x / 2) (n - 1);

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

    splitStringWithRegex =
      sep: s:
        let
          splits = builtins.filter builtins.isString (builtins.split (toString sep) (toString s));
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

  # TODO: Properly accept fractional exponents.
  power = x: n:
    if builtins.floor n == 0
    then 1
    else if n < 0
    then power (1 / x) (-n)
    else x * power x (n - 1);

  # No global seed to change, so there isn't much we can do.
  random_uniform = {}: 0.646355926896028;

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

  decode_bit_array =
    data:
      if data.__gleamBuiltIn or null == "BitArray"
      then Ok data
      else if builtins.isList data && builtins.all builtins.isInt data
      then Ok (toBitArray data)
      else decoder_error "BitArray" data;

  decode_tuple = data: if builtins.isList data then Ok data else decoder_error "Tuple" data;

  decode_tuple2 = decode_tupleN 2;
  decode_tuple3 = decode_tupleN 3;
  decode_tuple4 = decode_tupleN 4;
  decode_tuple5 = decode_tupleN 5;
  decode_tuple6 = decode_tupleN 6;
  decode_tupleN = n: data:
    let
      data_as_decoded_list = decode_exact_len_list data n;
    in
      if builtins.isList data && builtins.length data == n
      then Ok data
      else if isOk data_as_decoded_list
      then Ok data_as_decoded_list._0
      else decoder_error "Tuple of ${n} elements" data;

  decode_list =
    data:
      if builtins.isList data
      then Ok (toList data)
      else if data.__gleamBuiltIn or null == "List"
      then Ok data
      else decoder_error "List" data;

  decode_exact_len_list =
    data: n:
      if data.__gleamBuiltIn or null != "List"
      then Error Nil
      else if n == 0
      then if listIsEmpty data then Ok [] else Error Nil
      else if listIsEmpty data
      then Error Nil
      else
        let
          decoded_tail = decode_exact_len_list data.tail (n - 1);
        in
          if isOk decoded_tail
          then Ok ([ data.head ] ++ decoded_tail._0)
          else Error Nil;

  decode_option =
    data: decoder:
      if data == null || data.__gleamTag or null == "None"
      then Ok None
      else
        let
          innerData = if data.__gleamTag or null == "Some" then data._0 or data else data;
          decoded = decoder innerData;
        in if isOk decoded then Ok (Some decoded._0) else decoded;

  decode_field =
    data: originalName:
      let
        name = if builtins.isInt originalName then builtins.toString name else name;
        not_a_map_error = decoder_error "Dict" data;
      in
        if builtins.isAttrs data
        then
          if !(builtins.isString name)
          then Ok None
          else if data ? ${name}
          then Ok (Some data.${name})
          else if (builtins.isInt originalName || builtins.match "^[[:digit:]]+$" name != null) && data ? "_${name}"
          then Ok (Some data."_${name}") # heuristic to access positional fields of records
          else Ok None
        else not_a_map_error;

  tuple_get =
    data: index:
      if index >= 0 && builtins.length data > index
      then Ok (builtins.elemAt data index)
      else Error Nil;

  size_of_tuple = builtins.length;

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
        if data.__gleamBuiltIn or null == "List"
        then inspect_list data
        else if data.__gleamBuiltIn or null == "BitArray"
        then bit_array_inspect data
        else if data.__gleamTag or null == "Dict" && data ? _attrs && data ? _list
        then inspect_dict data
        else if data ? __gleamTag
        then inspect_record data
        else inspect_attrs data
      else "//nix(...)";  # TODO: Detect built-in data types, possibly others.

  inspect_attrs =
    data:
      let
        attr_mapper =
          a:
            let
              identifier_match = builtins.match "[a-zA-Z\_][a-zA-Z0-9\_\'\-]*";

              escaped_attr_name = if identifier_match a == null then "\"${a}\"" else a;

              # Stopgap for infinitely recursive attribute sets
              # We could perhaps use a recursive call counter in the future
              inspected_value =
                let
                  value = data.${a};
                in if builtins.isAttrs value then "//nix({ ... })" else inspect value;
            in " ${escaped_attr_name} = ${inspected_value};";

        attr_pairs = builtins.concatStringsSep "" (map attr_mapper (builtins.attrNames data));
      in "//nix({${attr_pairs} })";

  inspect_list =
    data:
      "[${builtins.concatStringsSep ", " (list_to_mapped_nix_list inspect data)}]";

  inspect_dict =
    data:
      "dict.from_list(${inspect_list (map_to_list data)})";

  inspect_record =
    data:
      let
        match_numeric_label = builtins.match "^_([[:digit:]]+)$";

        # We sort numeric labels so they aren't sorted lexicographically,
        # but rather the smallest number should come first.
        # Additionally, non-numeric labels are pushed to the end.
        label_comparator =
          a: b:
            let
              numeric-match-a = match_numeric_label a;
              numeric-match-b = match_numeric_label b;
              parsed-int-a = builtins.fromJSON (builtins.head numeric-match-a);
              parsed-int-b = builtins.fromJSON (builtins.head numeric-match-b);
            in
              if numeric-match-a != null && numeric-match-b != null
              then parsed-int-a < parsed-int-b
              else numeric-match-a != null;

        # Map a label to a "label: value" string (or just "value" if numeric).
        label_mapper =
          label:
            let
              is-numeric = match_numeric_label label != null;
              field = if is-numeric then "" else "${label}: ";
              v = inspect data."${label}";
            in field + v;

        label_filter = label: label != "__gleamTag" && label != "__gleamBuiltIn";

        label_value_pairs =
          map
            label_mapper
            (builtins.sort label_comparator (builtins.filter label_filter (builtins.attrNames data)));

        fields =
          if label_value_pairs == []
          then ""
          else "(${builtins.concatStringsSep ", " label_value_pairs})";
      in
        "${data.__gleamTag}${fields}";

  print = message: builtins.trace message null;

  add = a: b: a + b;

  concat = l: if l.__gleamTag == "Empty" then "" else l.head + concat l.tail;

  length = builtins.stringLength;

  lowercase = essentials.toLower;

  uppercase = essentials.toUpper;

  split = string: pattern: if pattern == "" then string_to_codepoint_strings string else essentials.splitString pattern string;

  split_once = string: pattern:
    let
      escapedPattern = essentials.escapeRegex pattern;
      splitResult = builtins.split "${escapedPattern}(([[:space:]]|[^[:space:]])+)$" string;
      splitHead = builtins.head splitResult;
      splitTail = builtins.head (builtins.elemAt splitResult 1);
    in
      if pattern == ""
      then Ok [ "" string ]
      else if builtins.length splitResult == 1
      then Error Nil
      else Ok [ splitHead splitTail ];

  string_replace = string: pattern: substitute: builtins.replaceStrings [pattern] [substitute] string;

  less_than = a: b: a < b;

  crop_string =
    string: substring:
      let
        splitOnceResult = split_once string substring;
      in
        if string == "" || !(isOk splitOnceResult)
        then string
        else substring + builtins.elemAt splitOnceResult._0 1;

  contains_string = haystack: needle: essentials.hasInfix needle haystack;

  starts_with = haystack: needle: essentials.hasPrefix needle haystack;

  ends_with = haystack: needle: essentials.hasSuffix needle haystack;

  trim = s:
    let
      matched = builtins.match "^[[:space:]]*(([[:space:]]|[^[:space:]])*[^[:space:]])[[:space:]]*$" s;
      # When it doesn't match, there are no non-whitespace characters.
      result = if matched == null then "" else builtins.head matched;
    in result;

  trim_left = s: builtins.head (builtins.match "^[[:space:]]*(([[:space:]]|[^[:space:]])*)$" s);

  trim_right = s:
    let
      matched = builtins.match "^(([[:space:]]|[^[:space:]])*[^[:space:]])[[:space:]]*$" s;
      # When it doesn't match, there are no non-whitespace characters.
      result = if matched == null then "" else builtins.head matched;
    in result;

  # --- codepoint code ---

  utf_codepoint_to_int = codepoint: codepoint.value;

  codepoint = UtfCodepoint;

  dec_to_hex = i: int_to_base_string i 16;

  int_codepoint_to_string =
    n:
      let
        hex = dec_to_hex n;
        zeroes = builtins.substring 0 (8 - (builtins.stringLength hex)) "00000000";
      in (builtins.fromTOML "x = \"\\U${zeroes}${hex}\"").x;

  # Performs a binary search of the given string among all possible codepoints.
  #
  # This is possible since strings are comparable, and codepoints
  # with a larger numeric value, when represented as strings (UTF-8 bytes),
  # compare larger than strings of codepoints of smaller value.
  # Therefore, if the string compares larger than the character
  # corresponding to the codepoint halfway through the range,
  # the string will be somewhere at the upper half of the codepoint
  # range; otherwise, at the lower half. If the string is equal to the character
  # at the half of the range, its codepoint value is returned, as it was found.
  #
  # When the string is not a valid codepoint, returns 0.
  string_to_codepoint_aux = let
      minInvalidChar = 55296; # 0xd800
      maxInvalidChar = 57343; # 0xdfff - codepoints in this range are invalid
    in s: min: max:
      let
        half = ((max + min) / 2);
        # Skip invalid codepoint range
        fixedHalf = if half >= minInvalidChar && half <= maxInvalidChar then maxInvalidChar + 1 else half;
        beforeHalf = if fixedHalf == maxInvalidChar + 1 then minInvalidChar - 1 else fixedHalf - 1;
        halfChar = int_codepoint_to_string fixedHalf;
      in
        if min > max
        then 0 # string isn't a valid UTF-8 codepoint
        else if s == halfChar
        then fixedHalf
        else if s > halfChar
        then string_to_codepoint_aux s (fixedHalf + 1) max
        else string_to_codepoint_aux s min beforeHalf;

  # Converts a string with a single codepoint to an integer.
  string_to_codepoint =
    let
      maxCharWith1Byte = 127;  # 0x007f
      maxCharWith2Bytes = 2047;  # 0x07ff
      maxCharWith3Bytes = 65535;  # 0xffff
      maxChar = 1114111;  # 0x10ffff
    in s:
      let
        len = builtins.stringLength s;
        # The string's amount of bytes determines its codepoint range.
        minMax =
          if len == 1
          then [ 0 maxCharWith1Byte ]
          else if len == 2
          then [ (maxCharWith1Byte + 1) maxCharWith2Bytes ]
          else if len == 3
          then [ (maxCharWith2Bytes + 1) maxCharWith3Bytes ]
          else [ (maxCharWith3Bytes + 1) maxChar ];

        min = builtins.head minMax;
        max = builtins.elemAt minMax 1;
      in string_to_codepoint_aux s min max;

  # TODO: Consider using genericClosure somehow
  string_to_codepoint_integer_list =
    let
      next = { codepoint, ... }: acc: prepend codepoint acc;
      init = toList [];
    in fold_string_codepoints { inherit next init; };

  # Take the codepoint starting at the given location in the string.
  # Also returns the amount of bytes in the codepoint.
  string_pop_codepoint_at =
    let
      firstCh = builtins.substring 0 1;
      last1Byte = 127;  # 0x007f
      last2Bytes = 2047;  # 0x07ff
      last3Bytes = 65535;  # 0xffff
      last1ByteFirstCh = firstCh (int_codepoint_to_string last1Byte);
      last2BytesFirstCh = firstCh (int_codepoint_to_string last2Bytes);
      last3BytesFirstCh = firstCh (int_codepoint_to_string last3Bytes);
    in
      s: cursor:
        let
          cursorByte = ascii_char_at cursor s;

          # The codepoint at the cursor might be represented using 1 to 4 bytes,
          # depending on the first byte's range.
          amountBytes =
            if cursorByte == ""
            then 0
            else if cursorByte <= last1ByteFirstCh
            then 1
            else if cursorByte <= last2BytesFirstCh
            then 2
            else if cursorByte <= last3BytesFirstCh
            then 3
            else 4;
          cursorUtfChar = builtins.substring cursor amountBytes s;
          cursorCodepoint =  if amountBytes == 0 then 0 else string_to_codepoint cursorUtfChar;
        in { codepoint = cursorCodepoint; utfChar = cursorUtfChar; inherit amountBytes; };

  # Folds over a string's codepoints.
  # The 'next' function combines the received codepoint with the accumulator to the right.
  # The 'init' value is returned when the string is empty, or we reached the end of it.
  fold_string_codepoints =
    { next, init }: s:
      let
        recurse = cursor:
          let
            cursorCodepointData = string_pop_codepoint_at s cursor;
            inherit (cursorCodepointData) amountBytes;
          in
            if amountBytes == 0
            then init
            else next cursorCodepointData (recurse (cursor + amountBytes));
      in recurse 0;

  utf_codepoint_list_to_string =
    l:
      let
        codepoint_at_head = utf_codepoint_to_int l.head;
        converted_head = int_codepoint_to_string codepoint_at_head;
      in
        if listIsEmpty l
        then ""
        else converted_head + utf_codepoint_list_to_string l.tail;

  # TODO: Count graphemes instead of codepoints.
  string_length =
    let
      next = { amountBytes, ... }: acc: amountBytes + acc;
      init = 0;
    in fold_string_codepoints { inherit next init; };

  # TODO: pop grapheme
  string_pop_first_codepoint =
    s:
      let
        codepointData = string_pop_codepoint_at s 0;
        firstCodepoint = codepointData.utfChar;
        restOfString = builtins.substring codepointData.amountBytes (-1) s;
      in
        if s == ""
        then Error Nil
        else Ok [ firstCodepoint restOfString ];

  # TODO: graphemes
  string_to_codepoint_strings =
    let
      next = { utfChar, ... }: acc: prepend utfChar acc;
      init = toList [];
    in fold_string_codepoints { inherit next init; };

  # --- regex ---
  Regex = expr: options: { __gleamTag = "Regex"; inherit expr options; };

  # TODO: Validate the expression to some extent
  # TODO: Normalize non-POSIX regexes into POSIX
  compile_regex =
    expr: options:
      builtins.seq
        (builtins.match expr "") # ensure program crashes early with bad regex
        Ok (Regex expr options);

  # TODO: Apply regex options
  regex_check = regex: string: builtins.match regex.expr string != null;

  regex_split = regex: string: essentials.splitStringWithRegex regex.expr string;

  regex_scan =
    regex: string:
      let
        matches = builtins.match regex.expr string;
        submatches = builtins.map (m: if m == null then None else Some m) matches;
      in
        if builtins.isNull matches
        then toList []
        else toList [ (Match string (toList submatches)) ]; # Nix regexes always apply to the whole input

  # --- bitarray code ---

  byte_size = byteSize;

  list_to_mapped_nix_list = f: l: if listIsEmpty l then [] else [ (f l.head) ] ++ list_to_mapped_nix_list f l.tail;

  bit_array_concat = arrays: toBitArray (list_to_mapped_nix_list (a: a.buffer) arrays);

  bit_array_inspect = array: "<<${builtins.concatStringsSep ", " (map builtins.toString array.buffer)}>>";
in
  {
    inherit
      Regex
      identity
      unimplemented0
      unimplemented
      unimplemented2
      unimplemented3
      unimplemented4
      parse_int
      int_from_base_string
      int_to_base_string
      bitwise_and
      bitwise_not
      bitwise_or
      bitwise_exclusive_or
      bitwise_shift_left
      bitwise_shift_right
      parse_float
      to_string
      float_to_string
      ceiling
      floor
      round
      truncate
      to_float
      power
      random_uniform
      classify_dynamic
      decode_string
      decode_int
      decode_float
      decode_bool
      decode_bit_array
      decode_tuple
      decode_tuple2
      decode_tuple3
      decode_tuple4
      decode_tuple5
      decode_tuple6
      decode_list
      decode_option
      decode_field
      tuple_get
      size_of_tuple
      decode_result
      inspect
      print
      add
      concat
      length
      lowercase
      uppercase
      split
      split_once
      string_replace
      less_than
      crop_string
      contains_string
      starts_with
      ends_with
      trim
      trim_left
      trim_right
      utf_codepoint_to_int
      codepoint
      string_to_codepoint_integer_list
      utf_codepoint_list_to_string
      string_length
      string_pop_first_codepoint
      string_to_codepoint_strings
      compile_regex
      regex_check
      regex_split
      regex_scan
      byte_size
      bit_array_concat
      bit_array_inspect
      new_map
      map_size
      map_get
      map_insert
      map_remove
      map_to_list;
  }
