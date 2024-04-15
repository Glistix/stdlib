# stdlib

<a href="https://github.com/Glistix/stdlib/releases"><img src="https://img.shields.io/github/release/Glistix/stdlib" alt="GitHub release"></a>
![CI](https://github.com/Glistix/stdlib/workflows/CI/badge.svg?branch=main)

This is a Glistix port of Gleam's standard library (https://github.com/gleam-lang/stdlib). Its documentation is availalbe [HexDocs](https://hexdocs.pm/gleam_stdlib/).

## Installation

It is recommended to use this repository as a Git dependency for now, in order to override the `gleam_stdlib` dependency of transitive dependencies as well.

If `glistix new` didn't automatically do this, follow the steps below.

1. Create a folder named `external` in your repository.

2. Run the command below to add this repository as a submodule. Whenever you clone your repository again, run `git submodule init` to restore the submodule's contents.

```sh
git submodule add https://github.com/Glistix/stdlib external/stdlib
```

3. Make `gleam_stdlib` a path dependency to the cloned repository instead of a Hex dependency. **Make sure to undo this step when publishing to Hex** (maybe even consider not commiting this step to your repository at all), since you can't publish Hex packages with path dependencies. To do this, edit the `[dependencies]` section in `gleam.toml` as below:

```sh
[dependencies]
gleam_stdlib = { path = "./external/stdlib" }
# Uncomment when publishing to Hex
# gleam_stdlib = "~> 0.35 or ~> 1.0"
```

4. Done, your code will now compile, and your dependencies will use the ported version of the standard library.

The same procedure is done for any Nix ports you may want to use in your project, e.g. `gleeunit`, `json`, `birl` and so on.

It is expected that this procedure will become simpler in the future, once Gleam gets Git dependencies and built-in patching
of dependencies.

## Inconsistencies and missing features on Nix

Compared to the standard library for other targets, the following functions **were not yet implemented on the Nix target** and will lead to a crash upon usage (**contributions welcome**):

- `bit_array`:
  - `encode64`
  - `decode64`
  - `base16_encode`
  - `base16_decode`

- `uri`:
  - `parse_query`
  - `percent_encode`
  - `percent_decode`

Additionally, the following functions currently have an **inconsistent implementation** with upstream:

- `string`:
  - `pop_grapheme`, `to_graphemes` and any functions depending on it (`length`, `split` and so on):
    - Will work with codepoints instead of graphemes, as **grapheme splitting wasn't yet implemented.**
      We need either a Nix or pure Gleam implementation.

- `regex`:
  - `compile` and `from_string`:
    - They use POSIX ERE regex syntax (the one supported by Nix), so libraries depending on e.g. `\s` or `\d`
    will fail to work (they'd need to use `[[:space:]]` or `[0-9]` instead). Same as libraries which escape `]`.
      - Ideally, we'd **manually parse the regex and fix those inconsistencies**. A simple global replace isn't
      viable for all cases, so we'd have to bear that in mind.
    - Invalid regexes **always cause a crash** instead of returning `Err`. We'd have to manually parse regex to
    detect and prevent this.
    - The "case insensitive" and "multiline" flags for `compile` currently don't do anything.

- `dict`:
  - Currently has `O(n)` complexity for arbitrary input, as no hashing is performed. It is, however, optimized
  for primitives such as strings and integers (by using Nix attribute sets), but not floats.

## Usage

Import the modules you want to use and write some code!

```gleam
import gleam/string

pub fn greet(name: String) -> String {
  string.concat(["Hello ", name, "!"])
}
```

## Targets

Supports Erlang, JavaScript and Nix.

### Compatibility

For Erlang and JavaScript targets, the same disclaimer as the actual
standard library applies:

"This library is compatible with all versions of Erlang/OTP, NodeJS, and
major browsers that are currently supported by their maintainers. If you
have a compatibility issue with any platform open an issue and we'll see
what we can do to help."

Regarding Nix, in principle we aim to support as many Nix versions as possible.
Most of the initial work has been done on Nix 2.18, but should be compatible
with prior versions. Let us know if you have any trouble by opening an issue.
