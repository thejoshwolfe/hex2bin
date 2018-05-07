# hex2bin

reverse hex dump

## Build

Install [zig](http://ziglang.org/).

```
$ mkdir build && cd build
$ zig build-exe --library c ../src/hex2bin.zig
```

Executable binary is at `build/hex2bin`.

## Run

```
hex2bin INPUT.zip OUTPUT.hex
```

## Syntax

TODO: document syntax

TODO: add support for cool stuff like `utf8"foo"` and u32le decimal literals.

## See Also

These projects produce hexdumps in the format consumed by this project:

* [hexdump-zip](https://github.com/thejoshwolfe/hexdump-zip)
