# ``CliVersion``

Derive a version for a command line tool from git tags or a git sha.

## Additional Resources

[Github Repo](https://github.com/m-housh/swift-cli-version)

## Overview

This tool exposes several plugins that can be used to derive a version for a command line program at
build time or by manually running the plugin.  The version is derived from git tags and falling back to 
the branch and git sha if a tag is not set for the current worktree state.

## Articles

- <doc:GettingStarted>
- <doc:ManualPlugins>

## Api

- ``FileClient``
- ``GitVersionClient``
