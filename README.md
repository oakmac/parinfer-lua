# Parinfer in Lua

The core [Parinfer] algorithm written in Lua.

[Parinfer]:http://shaunlebron.github.io/parinfer/

## Usage

This library mirrors [parinfer.js] nearly 1-for-1. Please see documentation
there for usage.

Note that this library uses 1 indexes (instead of 0) for things like `options.cursorX`,
`options.cursorLine`, `changes.lineNo`, etc in order to be compatible with the
rest of the Lua ecosystem.

The library is a single file (`parinfer.lua`) and has no external dependencies.
The libraries in the `libs/` folder are for development helpers and to run the
test suite.

[parinfer.js]:https://github.com/oakmac/parinfer

## Run Tests

```sh
lua tests.lua
```

## License

[ISC License](LICENSE.md)
