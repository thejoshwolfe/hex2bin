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
hex2bin INPUT.hex OUTPUT.bin
```

## Syntax

The input file must use unix line endings, and the last line must be blank.

Here is an example of a complete file:

```
; comment
:0x00 ; offset directive
68 65 6c 6c 6f 20 77 6f 72 6c 64 0a ; the text "hello world\n"

:0x0c ; offset directive
```


### Comment

Comments start with `;` and end at the end of the line.

```
; this is a comment
```

### Byte

A byte is encoded as a sequence of two nibbles, where a nibble is `0`-`9`, `A`-`F`, `a`-`f`.

```
05 0a 0f 14 ; four bytes with decimal values 5, 10, 15, 20
```

The nibbles that encode a byte must be immediately adjacent to each other.

```
0 0 ; error
```

Nibbles from different bytes must not be immediately adjacent to each other.
This is to make sure there's no confusion about big/little endian byte order.

```
0000 ; error
```

The output of the program simply the sequence of bytes encoded by these nibble sequences.

### Offset Directive

An offset directive is optional and simply asserts the byte offset of the output at the current position in the input file.
An offset directive starts with `:0x`, followed by 1 or more nibbles, and terminated by the first non-nibble character.

```
:0x00 ; offset starts at 0
68 65 6c 6c 6f 20 77 6f 72 6c 64 0a ; the text "hello world\n"
:0x0c ; we've encountered 12 bytes so far
:0x0d ; this is an error; we're still at offset 12
```

### Other fun stuff maybe

TODO: add support for cool stuff like `utf8"foo"` and u32le decimal literals.

## See Also

This project produces hexdumps in the format consumed by this project:

* [hexdump-zip](https://github.com/thejoshwolfe/hexdump-zip)
