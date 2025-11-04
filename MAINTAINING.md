# Starkup Maintenance

## Automated version updates

The [Auto Update Tool Versions] workflow runs on weekdays at 6:00 AM UTC and monitors for new stable releases of:
- [Scarb] (from `software-mansion/scarb`)
- [Starknet Foundry] (from `foundry-rs/starknet-foundry`)

When a new stable release is detected, the workflow automatically:
1. Creates a new branch
2. Updates the corresponding `*_LATEST_COMPATIBLE_VERSION` variable in `starkup.sh`
3. Bumps the `SCRIPT_VERSION` (patch version) to prepare for a new starkup release
4. Opens a pull request with the changes
5. Requests reviews from users specified in the `AUTO_UPDATE_REVIEWERS` repository variable (if configured)

To configure reviewers, set the `AUTO_UPDATE_REVIEWERS` repository variable to a comma-separated list of GitHub usernames (e.g., `user1,user2`).

The workflow can also be triggered manually via the Actions tab.

[Auto Update Tool Versions]: https://github.com/software-mansion/starkup/blob/main/.github/workflows/auto-update-tools.yml
[Scarb]: https://github.com/software-mansion/scarb
[Starknet Foundry]: https://github.com/foundry-rs/starknet-foundry

## Release procedure

### Cut new version

In a nutshell, this is trivial: create a tag on `main` named `vX.Y.Z`.
There is a tag protection rule set up!
Make sure you create it on a green commit (CI is passing), otherwise your tag will be rejected by remote!
A tag should trigger a [Release] workflow which uploads the script to [sh.starkup.dev](https://sh.starkup.dev), verifies the upload and drafts a GitHub release.

### Publish release notes

Upon completion, the [Release] workflow should draft a release on GitHub.
Usually, it's enough to publish the auto-generated release notes. 

[release]: https://github.com/software-mansion/starkup/blob/main/.github/workflows/release.yml
