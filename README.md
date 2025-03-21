# starkup: the Cairo toolchain installer

Starkup helps you install all the tools you will use to develop packages in [Cairo] and write contracts for [Starknet].

## Getting started

Run the following in your terminal, then follow the onscreen instructions.

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.starkup.sh | sh
```

## Supported tools

Starkup supports the installation of the following tools:

- [Scarb] the Cairo package manager
- [Starknet Foundry] the Cairo and Starknet testing framework
- [Universal Sierra Compiler] compiler for any ever-existing Sierra version
- [Cairo Profiler] profiler for Cairo programming language & Starknet
- [Cairo Coverage] utility for coverage reports generation for code written in Cairo programming language
- [CairoLS] vscode extension

## Installing specific versions

Starkup allows you to choose which versions of tools to install using the `--version-set` flag.
The following version sets are available:

- `compatible` (default): Installs versions of all tools that are known to be compatible with each other
- `latest`: Installs latest versions of all tools, which **may be incompatible** with each other

To install a specific version set (e.g. `latest`), run the following:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.starkup.dev | sh -s -- --version-set latest
```

## Architecture

Starkup relies on [ASDF] package manager to install the latest versions of [Scarb] and [Starknet Foundry]. If you don't have [ASDF] yet, no worries - Starkup can handle that as well!

## Community

Starkup is created by the same team at [Software Mansion] that is behind [Scarb] the Cairo package manager and [Starknet Foundry], the Cairo and Starknet testing framework. We partnered with [Starkware], the creators of [Cairo] and [Starknet].

Feel free to chat with us on our channel on [Telegram] or [Starknet's Discord]!

[Cairo]: https://www.cairo-lang.org/
[Scarb]: https://docs.swmansion.com/scarb/
[Software Mansion]: https://swmansion.com/
[Starknet Foundry]: https://foundry-rs.github.io/starknet-foundry/
[Cairo Profiler]: https://github.com/software-mansion/cairo-profiler
[Cairo Coverage]: https://github.com/software-mansion/cairo-coverage
[CairoLS]: https://github.com/software-mansion/cairols
[Starknet]: https://www.starknet.io/what-is-starknet/
[Universal Sierra Compiler]: https://github.com/software-mansion/universal-sierra-compiler
[ASDF]: https://asdf-vm.com/guide/getting-started.html
[Telegram]: https://t.me/+G_YxIv-XTFlhNWU0
[Starknet's Discord]: https://discord.gg/rKzsYaTMvA
