#!/bin/sh
# shellcheck shell=dash

set -eu

ASDF_INSTALL_DOCS="https://asdf-vm.com/guide/getting-started.html"
SCARB_UNINSTALL_DOCS="https://docs.swmansion.com/scarb/download#uninstall"
STARKNET_FOUNDRY_UNINSTALL_DOCS="PENDING"
SCRIPT_VERSION="0.1.0"
DEFAULT_ASDF_VERSION="v0.14.1"

usage() {
	cat <<EOF
The installer for Starknet tools. Installs the latest versions of Scarb, Starknet Foundry and Universal Sierra Compiler using asdf.

Usage: $0 [OPTIONS]

Options:
  -h, --help      Print help
  -V, --version   Print script version

EOF
}

main() {
	for arg in "$@"; do
		case "$arg" in
		-h | --help)
			usage
			exit 0
			;;
		-V | --version)
			printf "starknetup %s\n" "$SCRIPT_VERSION"
			exit 0
			;;
		*)
			err "invalid option '$arg'. For more information, try '--help'."
			;;
		esac
	done

	assert_dependencies
	assert_not_installed "scarb" $SCARB_UNINSTALL_DOCS
	install_latest_asdf_plugin "scarb"
	install_latest_version "scarb"
	set_global_latest_version "scarb"

	assert_not_installed "starknet-foundry" $STARKNET_FOUNDRY_UNINSTALL_DOCS
	install_latest_asdf_plugin "starknet-foundry"

	# Reinstall to ensure the latest version of USC is installed
	uninstall_latest_version "starknet-foundry"
	install_latest_version "starknet-foundry"
	set_global_latest_version "starknet-foundry"

	say "Installation complete"
}

assert_dependencies() {
	need_cmd curl
	need_cmd git
	if ! check_cmd asdf; then
		install_asdf_interactively
	fi
}

assert_not_installed() {
	local tool="$1"
	local uninstall_docs_url="$2"

	if ! asdf which "$tool" >/dev/null 2>&1; then
		if check_cmd "$tool"; then
			err "$tool is already installed outside of asdf. Please uninstall it and re-run this script. For uninstallation instructions, refer to $uninstall_docs_url."
		fi
	fi
}

install_latest_asdf_plugin() {
	local plugin="$1"
	if asdf plugin list | grep -q "$plugin"; then
		ensure asdf plugin update "$plugin"
	else
		ensure asdf plugin add "$plugin"
	fi
}

install_latest_version() {
	local tool="$1"
	ensure asdf install "$tool" latest
}

uninstall_latest_version() {
	local tool="$1"
	local latest_version
	latest_version=$(asdf latest "$tool")

	if asdf list "$tool" "^${latest_version}$" >/dev/null 2>&1; then
		ensure asdf uninstall "$tool" "$latest_version"
	fi
}

set_global_latest_version() {
	local tool="$1"
	ensure asdf global "$tool" latest
}

say() {
	printf "starknetup: %s\n" "$1"
}

err() {
	say "$1" >&2
	exit 1
}

need_cmd() {
	if ! check_cmd "$1"; then
		err "need '$1' (command not found)"
	fi
}

check_cmd() {
	command -v "$1" >/dev/null 2>&1
}

ensure() {
	if ! "$@"; then err "command failed: $*"; fi
}

install_asdf_interactively() {
	local _profile
	local _pref_shell
	local _asdf_path="$HOME/.asdf"

	case ${SHELL:-""} in
	*/zsh)
		_profile=$HOME/.zshrc
		_pref_shell=zsh
		;;
	*/ash)
		_profile=$HOME/.profile
		_pref_shell=ash
		;;
	*/bash)
		if [ "$(uname)" = "Darwin" ]; then
			_profile=$HOME/.bash_profile
		else
			_profile=$HOME/.bashrc
		fi
		_pref_shell=bash
		;;
	*)
		err "asdf-vm is required. Please install it manually and re-run this script. For installation instructions, refer to ${ASDF_INSTALL_DOCS}."
		;;
	esac

	if [ -n "$_profile" ]; then
		if [ ! -f "$_profile" ]; then
			touch "$_profile"
		fi

		say "asdf-vm is required. Do you want to install it now? (y/N): "
		read -r answer
		case $answer in
		[Yy]*)
			latest_asdf_version=$(curl -s https://api.github.com/repos/asdf-vm/asdf/releases/latest | awk -F'"' '/"tag_name"/ {print $4}') || latest_asdf_version="$DEFAULT_ASDF_VERSION"

			say "Installing asdf-vm ${latest_asdf_version}...\n"
			git clone https://github.com/asdf-vm/asdf.git "$_asdf_path" --branch "$latest_asdf_version"

			case $_pref_shell in
			zsh | bash | ash)
				echo >>"$_profile" && echo ". ${_asdf_path}/asdf.sh" >>"$_profile"
				;;
			esac

			say "asdf-vm has been installed. Run 'source ${_profile}' or start a new terminal session and re-run this script."
			exit 0
			;;
		*)
			err "asdf-vm is required. Please install it manually and re-run this script. For installation instructions, refer to ${ASDF_INSTALL_DOCS}."
			;;
		esac
	else
		err "asdf-vm is required. Please install it manually and re-run this script. For installation instructions, refer to ${ASDF_INSTALL_DOCS}."
	fi
}

main "$@" || exit 1
