# Starkup Maintenance

## Release procedure

### Cut new version

In a nutshell, this is trivial: create a tag on `main` named `vX.Y.Z`.
There is a tag protection rule set up!
Make sure you create it on a green commit (CI is passing), otherwise your tag will be rejected by remote!
A tag should trigger a [Release] workflow which uploads the script to [sh.starkup.dev](https://sh.starkup.dev), verifies the upload and drafts a GitHub release.

### Publish release notes

Upon completion, the [Release] workflow should publish a release on GitHub.
Usually, it's enough to publish the auto-generated release notes.

[release]: https://github.com/software-mansion/starkup/blob/main/.github/workflows/release.yml
