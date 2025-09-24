# starkup: the Cairo toolchain installer

Starkup helps you install all the tools you will use to develop packages in [Cairo] and write contracts for [Starknet].

## Getting started

Run the following in your terminal, then follow the onscreen instructions.

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.starkup.sh | sh
```

## Supported tools

Starkup supports the installation of the following tools:

- [Scarb]: package manager for Cairo
- [Starknet Foundry]: testing framework for Cairo and Starknet
- [Starknet Devnet]: local testnet for Starknet
- [Universal Sierra Compiler]: compiler for any existing or past Sierra version
- [Cairo Profiler]: profiler for Cairo and Starknet
- [Cairo Coverage]: coverage report generator for Cairo
- [CairoLS]: VS code extension for Cairo

## Installing specific versions

Starkup allows you to choose which versions of tools to install using the `--version-set` flag.
The following version sets are available:

- `compatible` (default): Installs versions of all tools that are known to be compatible with each other
- `latest`: Installs latest versions of all tools, which **may be incompatible** with each other

To install a specific version set (e.g. `latest`), run the following:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.starkup.sh | sh -s -- --version-set latest
```

## Architecture

Starkup relies on [ASDF] package manager to install the latest versions of [Scarb] and [Starknet Foundry]. If you don't have [ASDF] yet, no worries - Starkup can handle that as well!

## Community

Starkup is created by the same team at [Software Mansion] that is behind [Scarb] the Cairo package manager and [Starknet Foundry], the Cairo and Starknet testing framework. We partnered with [Starkware], the creators of [Cairo] and [Starknet].

Feel free to chat with us on our channel on [Telegram] or [Starknet's Discord]!

## Troubleshooting

If you have `curl` installed through `snap` store, Starkup may fail with following error:

```sh
curl: (23) client returned ERROR on write of 1317 bytes
```

To make sure if `curl` is installed via `snap`, you can run this command:

```sh
$ sudo snap list | grep curl
```

In this case, you should try reinstalling `curl` from other distribution channels. 
For instance, on Debian / Ubuntu based systems you can try running:
```sh
$ sudo snap remove curl
$ sudo apt install curl
```


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
[Starknet Devnet]: https://0xspaceshard.github.io/starknet-devnet
