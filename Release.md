# Release Workflow Steps

This is a reminder of the steps used to create a release and update the homebrew formula.

> Note: These steps apply to the version hosted on `gitea`, on `github` more of these steps can be
> automated in `ci`, but there are no `macOS` host runners currently in `gitea`, so the bottles need
> built on `macOS`.

1. Update the version in `Sources/hpa/Version.swift`.
1. Tag the commit with the next version tag.
1. Push the tagged commit, this will initiate the release being created.
1. Get the `sha` of the `*.tar.gz` in the release.
   1. `just get-release-sha`
1. Update the homebrew formula url, sha256, and version at top of the homebrew formula.
   1. `cd $(brew --repo michael/formula)`
1. Build and generate a homebrew bottle.
   1. `just bottle`
1. Update the `bottle do` section of homebrew formula with output during previous step.
   1. Also make sure the `root_url` in the bottle section points to the new release.
1. Upload the bottle `*.tar.gz` file that was created to the release.
1. Generate a pull-request to the formula repo.
1. Generate a pull-request to this repo to merge into main.
1. Remove the bottle from current directory.
   1. `just remove-bottles`
