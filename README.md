# stdlib

<a href="https://github.com/Glistix/stdlib/releases"><img src="https://img.shields.io/github/release/Glistix/stdlib" alt="GitHub release"></a>
[![test](https://github.com/Glistix/stdlib/actions/workflows/test.yml/badge.svg)](https://github.com/Glistix/stdlib/actions/workflows/test.yml)
[![Nix-compatible](https://img.shields.io/badge/target-nix-5277C3)](https://github.com/glistix/glistix)

**Mirrors:** [**GitHub**](https://github.com/Glistix/stdlib) | [**Codeberg**](https://codeberg.org/Glistix/stdlib)

This is a port of Gleam's standard library (https://github.com/gleam-lang/stdlib) to Glistix's Nix target. Documentation is available on [HexDocs](https://hexdocs.pm/glistix_stdlib/).

**Note:** This is a Glistix project, and as such may require the
[Glistix compiler](https://github.com/glistix/glistix) to be used.

## Installation

_For the most recent instructions, please see [the Glistix handbook](https://glistix.github.io/book/recipes/overriding-packages.html)._

This fork is available on Hex and already installed by default on any new Glistix projects using `glistix new`.

For existing projects, you can use this fork by running `glistix add gleam_stdlib` followed by adding the line below to your Glistix project's `gleam.toml` file (as of Glistix v0.7.0):

```toml
[glistix.preview.patch]
# ... Existing patches ...
# Add this line:
gleam_stdlib = { name = "glistix_stdlib", version = ">= 0.34.0 and < 2.0.0" }
```

This ensures transitive dependencies on `gleam_stdlib` will also use the patch.

Keep in mind that patches only have an effect on end users' projects - they are ignored when publishing a package to Hex, so end users are responsible for any patches their dependencies may need.

If your project or package is only meant for the Nix target, you can also use this fork in `[dependencies]` directly through `glistix add glistix_stdlib` in order to not rely on patching. However, the patch above is still going to be necessary for end users to fix other dependencies which depend on `gleam_stdlib`.

## Inconsistencies and missing features on Nix

Compared to the standard library for other targets, the following functions **were not yet implemented on the Nix target** and **will lead to a crash** upon usage (**contributions welcome**):

- `bit_array`:
  - `encode64`
  - `decode64`
  - `base16_encode`
  - `base16_decode`

- `uri`:
  - `parse_query`
  - `percent_encode`
  - `percent_decode`

Additionally, the following functions currently have an **inconsistent implementation on the Nix target**
compared to the Erlang and JavaScript targets:

- `dict`:
  - Currently has `O(n)` complexity for arbitrary key types, as no hashing is performed. It is, however,
  **optimized for primitives** such as strings and integers (by using Nix attribute sets), **but not floats.**

- `float`:
  - `random`: [**Always generates the same number** due to purity.](https://xkcd.com/221/)

- `int`:
  - `power`: **Does not support float exponents** (they are rounded down), **except for `0.5`** (computes square root).
  - `random`: Calls `float.random` and thus will also always generate the same results for the same inputs due to purity.
    - It won't always return the same value in every case, as the arguments can constrain what it can return, but in the
      general case the value will be the same.

- `string`:
  - `pop_grapheme`, `to_graphemes` and any functions depending on it (`length`, `split` and so on):
    - Will use codepoints instead of graphemes, as **grapheme splitting wasn't yet implemented.**
      We need either a Nix or pure Gleam implementation.

- `regex`:
  - `compile` and `from_string`:
    - **They use POSIX ERE regex syntax** (the one supported by Nix), so libraries depending on e.g. `\s` or `\d`
    will fail to work (they'd need to use `[[:space:]]` or `[0-9]` instead). Same as libraries which escape `]`.
      - Ideally, we'd **manually parse the regex and fix those inconsistencies**. A simple global replace on the
      expression isn't viable for all cases, so we'd have to bear that in mind.
    - **Invalid regexes always cause a crash** instead of returning `Err`. We'd have to manually parse regex to
    detect and prevent this.
    - The **"case insensitive" and "multiline" flags** for `compile` currently **don't do anything.**

## Usage

Import the modules you want to use and write some code!

```gleam
import gleam/string

pub fn greet(name: String) -> String {
  string.concat(["Hello ", name, "!"])
}
```

## Targets

Supports Erlang, JavaScript and Nix (requires Glistix).

### Compatibility

For Erlang and JavaScript targets, the same disclaimer as `gleam_stdlib`
applies:

"This library is compatible with all versions of Erlang/OTP, NodeJS, and
major browsers that are currently supported by their maintainers. If you
have a compatibility issue with any platform open an issue and we'll see
what we can do to help."

Regarding Nix, in principle we aim to support as many Nix 2.x versions as possible.
Most of the initial work has been done on Nix 2.18, but should be compatible
with prior versions (we haven't yet tested to which extent). Let us know if you have
any trouble by opening an issue.
