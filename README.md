# Avocado

A Forth for Linux and macOS on x86-64.

Avocado is written mostly in (indirect-)threaded code. There is no limit on the amount of primitives, however, each primitive should be kept small.

Since .text and .data are not mixed, CPU caches stay clean.

## Requirements

* `make`
* `gcc` or `clang`
* `ffmpeg` to generate `demo.png`

## Errors

Upon a word not found, Avocado outputs it, followed by a question mark.

Avocado will compile a definition without the words not found.

If Avocado crashes while defining a word, it most likely ran out of statically allocated memory.
