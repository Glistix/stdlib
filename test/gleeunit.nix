# This file is a verbatim copy of the equivalent file at the gleeunit fork with Nix support
let
  # Path of the root of the project
  # Assumes root/build/dev/nix/gleeunit as the current directory
  # :: path
  projectRootPath = ./../../../../.;

  # Contents of the 'gleam.toml' file of this project
  # :: string
  rootConfig =
    let
      gleamTomlPath = projectRootPath + "/gleam.toml";
    in
      if builtins.pathExists gleamTomlPath
      then builtins.readFile gleamTomlPath
      else builtins.abort "'gleam.toml' does not seem to be present in the project root, or gleeunit wasn't compiled to 'build/dev/nix'";

  # Name of the root package of this project
  # :: string
  rootPackageName =
    let
      lines = builtins.split "\n" rootConfig;
      matchNameLine =
        line:
          let
            matchedName = builtins.match "[[:space:]]*name[[:space:]]*=[[:space:]]*\"([a-z][a-z0-9_]*)\"" line;
          in
            if matchedName == null
            then null
            else builtins.head matchedName;

      nameSearcher =
        acc: elem:
          if acc != null || !builtins.isString elem
          then acc # we already found the line we were looking for, or this isn't a string
          else matchNameLine elem; # try to match this line, keep trying until not null

      foundName = builtins.foldl' nameSearcher null lines;
    in
      if foundName == null
      then builtins.abort "Could not determine package name from gleam.toml"
      else foundName;

  gleamSuffix = ".gleam";
  gleamLen = builtins.stringLength gleamSuffix;

  # Tests if a string has a particular suffix
  # :: string -> string -> bool
  hasSuffix = suffix: str:
    let
      suffixLen = builtins.stringLength suffix;
      strLen = builtins.stringLength str;
    in strLen >= suffixLen && suffix == builtins.substring (strLen - suffixLen) (-1) str;

  # Find all Gleam files in some `test/` subdirectory, recursively
  # :: string -> [string]
  gleamTestFilesAt =
    dirPath:
      let
        dir = builtins.readDir (projectRootPath + "/test/${dirPath}");
        mapSubpathToFiles =
          subpath: type:
            let
              slash = if dirPath == "" then "" else "/"; # no leading slash
              relativeSubpath = dirPath + "${slash}${subpath}";
              endsWithGleam = hasSuffix gleamSuffix;
            in
              if type == "directory"
              then gleamTestFilesAt relativeSubpath
              else if endsWithGleam relativeSubpath
              then [ relativeSubpath ]
              else [ ];

        mapDirAttrNamesToGleamFiles =
          subpath:
            mapSubpathToFiles subpath dir.${subpath};

        subpaths = builtins.attrNames dir;
      in builtins.concatMap mapDirAttrNamesToGleamFiles subpaths;

  # All Gleam files under `test/`
  # :: [string]
  gleamTestFiles = gleamTestFilesAt "";

  compiledFilesRoot = ./../${rootPackageName};

  # Removes `.gleam` at the end of a string
  # :: string -> string
  stripGleamSuffix =
    file:
      let
        fileLen = builtins.stringLength file;
      in
        if fileLen < gleamLen
        then file
        else builtins.substring 0 (fileLen - gleamLen) file;

  # Converts the relative path of the `.gleam` test file under `test/`
  # to a relative path to the `.nix` compiled file under `build/dev/nix/`
  # :: string -> path
  compiledTestFile =
    testFileSubpath:
      let
        compiledNixFile = file: "${stripGleamSuffix file}.nix";
        compiledNixPath = file: compiledFilesRoot + "/${compiledNixFile file}";
      in compiledNixPath testFileSubpath;

  # Tests all functions in a module, given the current state
  # of test results, the module name and the exported module contents.
  # Returns the new test result state after testing this module.
  #
  # :: AttrSet -> string -> any -> AttrSet
  testModule =
    results: module: exports:
      let
        mayBeTestableFunction = hasSuffix "_test";
        testMember =
          results: member:
            if mayBeTestableFunction member && builtins.isFunction exports.${member}
            then testFunction results member
            else results;

        testFunction =
          { message, tests, failures }: functionName:
            let
              function = exports.${functionName};
              call = function {}; # must have zero parameters for this to work
              evaluation = builtins.tryEval (builtins.deepSeq call call);
              results =
                if evaluation.success
                then { inherit failures; message = message + "."; tests = tests + 1; }
                else
                  {
                    message = message + "\n❌ ${module}.${functionName} failed\n";
                    tests = tests + 1;
                    failures = failures + 1;
                  };
            in results;

        exportedMembers = builtins.attrNames exports;
      in
        if builtins.isAttrs exports
        then builtins.foldl' testMember results exportedMembers
        else results;

  # Compiled test results
  # :: AttrSet
  testResults =
    builtins.foldl'
      (results@{ message, ... }: testPath:
        let
          module = stripGleamSuffix testPath;
          compiledTestModulePath = compiledTestFile testPath;
          testExpression = builtins.import compiledTestModulePath;
          newResults = testModule results module testExpression;
        in
          if builtins.pathExists compiledTestModulePath
          then newResults
          else results // { message = message + "\n⚠ ${module} wasn't compiled; ignoring\n"; })
      { message = ""; tests = 0; failures = 0; }
      gleamTestFiles;

  main =
    {}:
      let
        failures = if testResults.failures == 1 then "failure" else "failures";
        testResultMessage = "${testResults.message}\n${builtins.toString testResults.tests} tests, ${builtins.toString testResults.failures} ${failures}";
      in
        if testResults.failures == 0
        then builtins.trace testResultMessage null
        else builtins.throw "Some tests failed.\n${testResultMessage}";
in { inherit main; }
