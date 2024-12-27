# Basic Configuration

Basic configuration examples.

## Overview

Generating a configuration file for your application is the easiest way to use the command-line
tool. The configuration specifies the location of the version file, either by a path to the file or
by the module that a `Version.swift` file resides in. It also declares the strategy for generating
new versions.

The command-line tool comes with a command to generate the configuration file for you, this should
be ran from the root of your project.

```bash
bump-version config generate --target-module my-tool
```

The above command produces the following in a file named `.bump-version.json` with the generated
default settings. This will generate semvar style version (example: `1.0.0`).

```json
{
  "strategy": {
    "semvar": {
      "allowPreRelease": true,
      "strategy": {
        "gitTag": {
          "exactMatch": false
        }
      }
    }
  },
  "target": {
    "module": {
      "name": "my-tool"
    }
  }
}
```

> Note: The above does not add a pre-release strategy although it "allows" it if you pass an option
> to command later, if you set "allowPreRelease" to false it will ignore any attempts to add a
> pre-release strategy when bumping the version.

Most commands accept the same options for configuration as the above `config generate` command.
Those get merged with your project configuration when calling a command, that allows you to override
any of your defaults depending on your use case. You can also generate several configuration files
and specify them by passing the `-f | --configuration-file` to the command.

## Inspecting parsed configuration.

You can inspect the configuration that get's parsed by using the `config dump` command. The dump
command will print the parsed `json` to `stdout`, which can be helpful in confirming that your
configuration is valid and does not work unexpectedly.

```bash
bump-version config dump <options / overrides>
```

The dump command can also be used to generate a different configuration that is merged with your
default.

```bash
bump-version config dump --pre-release-git-tag-style > .bump-version.prerelease.json
```

Which would produce the following in `.bump-version.prerelease.json`

```json
{
  "strategy": {
    "semvar": {
      "allowPreRelease": true,
      "preRelease": {
        "strategy": {
          "gitTag": {}
        }
      },
      "strategy": {
        "gitTag": {
          "exactMatch": false
        }
      }
    }
  },
  "target": {
    "module": {
      "name": "my-tool"
    }
  }
}
```

You could then use this file when bumping your version.

```bash
bump-version bump -f .bump-version.prerelease.json
```

> See Also: <doc:ConfigurationReference>
