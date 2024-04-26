# stdlib

<a href="https://github.com/Glistix/stdlib/releases"><img src="https://img.shields.io/github/release/Glistix/stdlib" alt="GitHub release"></a>
[![test](https://github.com/Glistix/stdlib/actions/workflows/test.yml/badge.svg)](https://github.com/Glistix/stdlib/actions/workflows/test.yml)

**Mirrors:** [**GitHub**](https://github.com/Glistix/stdlib) | [**Codeberg**](https://codeberg.org/Glistix/stdlib)

This is a port of Gleam's standard library (https://github.com/gleam-lang/stdlib) to Glistix's Nix target. Its original documentation is available on [HexDocs](https://hexdocs.pm/gleam_stdlib/).

**Note:** This is a Glistix project, and as such may require the
[Glistix compiler](https://github.com/glistix/glistix) to be used.

## Installation

**It is recommended to use this repository as a Git dependency** for now, in order to override the `gleam_stdlib` dependency of transitive dependencies as well.

However, since Gleam (and thus Glistix) doesn't support Git dependencies, **you will have to add this repository as a local dependency to a Git submodule**
(at least for now).

If `glistix new` didn't automatically do this for you, follow the steps below.

1. Create a folder named `external` in your repository.

2. Run the command below to add this repository as a submodule. Whenever you clone your repository again, run `git submodule init` to restore the submodule's contents.

```sh
git submodule add --name stdlib -- https://github.com/Glistix/stdlib external/stdlib
```

3. Make `gleam_stdlib` a path dependency to the cloned repository instead of a Hex dependency.
To do this, edit the `[dependencies]` section in `gleam.toml` as below:

```toml
[dependencies]
gleam_stdlib = { path = "./external/stdlib" }
```

4. Hex doesn't allow local dependencies on packages. Therefore, as a temporary workaround,
**add the following section to `gleam.toml` so you can publish to Hex:**

```toml
[glistix.preview.hex-patch]
gleam_stdlib = ">= 0.34.0 and < 2.0.0"
```

5. Note that you may also have to add the section below if you use other submodules which also depend on stdlib
(otherwise you might have conflicts between different patches) - again, a temporary workaround for now:

```toml
[glistix.preview]
local-overrides = ["gleam_stdlib"]
```

6. Done, your code will now compile, and your dependencies will use the ported version of the standard library.

(**Note:** You may have to update your `flake.nix` as well to add the repository as a Flake input and pass it
to the `submodules` list given to `loadGlistixPackage` so that building through Nix works as well.
This is also done by default for `stdlib` by `glistix new`, but is something to consider when adding other
Git submodules as dependencies of your project.)

The same procedure is done for any Nix ports you may want to use in your project, e.g. [`json`](https://github.com/Glistix/json), [`birl`](https://github.com/Glistix/birl) and so on.

It is expected that this procedure will become simpler in the future, once Gleam gets Git dependencies and built-in patching
of dependencies.

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
