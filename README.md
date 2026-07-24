# cu

Cross-platform computer-use CLI. One verb, the right OS primitive.

The agent writes the same command on every OS; cu detects the platform and
translates to the native primitive (osascript on macOS, SendKeys on Windows,
xdotool on Linux).

```sh
cu capture out.png        # screencapture / import / GDI CopyFromScreen
cu type "hello"           # osascript / xdotool / SendKeys
cu key cmd+a              # chord mapped to each OS input plane
cu launch TextEdit
cu move 200 200
cu scroll down 3
cu select-all | copy | paste
cu os                     # which platform
cu <action> --json        # structured Result for agents
```

## Design

- **Pure core, tested.** Command mapping (`src/commands.ts`, `src/os.ts`) is pure
  functions: which argv each action becomes per OS. Fully unit-tested with no
  machine side effects. The CLI (`src/cli.ts`) only wires execution around them.
- **Structured output.** Every action returns a typed `Result` ({ok, action, os,
  detail?, error?}); `--json` emits it for agents. Failures are structured, never
  silent.
- **Ships as a binary.** `bun build --compile` produces a standalone executable,
  no runtime to install (kills the node-shebang problem for good).

## Develop

```sh
bun test          # 18 tests, the agnostic core
bun run build     # compile a standalone binary to dist/cu
```

## Status

v2 is a TypeScript rewrite of the original bash spike (kept as
`bin/cu-legacy.sh`). Tested on macOS, Windows, Linux via CI matrix. Built by Kai.
