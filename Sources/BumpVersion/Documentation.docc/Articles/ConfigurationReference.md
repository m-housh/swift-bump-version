# Configuration Reference

Learn about the configuration.

## Target

The target declares where a version file lives that can be bumped by the command-line tool.

A target can be specified either as a path from the root of the project to a file that contains the
version or as a module that contains the version file.

> Note: A version file should not contain any other code aside from the version as the entire file
> contents get over written when bumping the version.

### Target - Path Example

```json
{
  "target": {
    "path": "Sources/my-tool/Version.swift"
  }
}
```

### Target - Module Example

When using the module style a file name is not required if you use the default file name of
`Version.swift`, however it can be customized in your target specification.

```json
{
  "target": {
    "module": {
      "fileName": "CustomVersion.swift",
      "name": "my-tool"
    }
  }
}
```

The above will parse the path to the file as `Sources/my-tool/CustomVersion.swift`.

## Strategy

The strategy declares how to generate the next version of your project. There are currently two
strategies, `branch` and `semvar`, that we will discuss.

### Branch Strategy

This is the most basic strategy, which will derive the version via the git branch and optionally the
short version of the commit sha.

An example of this style may look like: `main-8d73287a60`.

```json
{
  "strategy": {
    "branch": {
      "includeCommitSha": true
    }
  }
}
```

If you set `'"includeCommitSha" : false'` then only the branch name will be used.

### Semvar Strategy

This is the most common strategy to use. It has support for generating the next version using either
`gitTag` or a custom `command` strategy.

#### Git Tag Strategy

The `gitTag` strategy derives the next version using the output of `git describe --tags` command.
This requires a commit to have a semvar style tag in it's history, otherwise we will use `0.0.0` as
the tag until a commit is tagged.

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
  }
}
```

If you set `'"exactMatch": true'` then bumping the version will fail on commits that are not
specifically tagged.

#### Custom Command Strategy

The custom `command` strategy allows you to call an external command to derive the next version. The
external command should return something that can be parsed as a semvar.

```json
{
  "strategy": {
    "semvar": {
      "allowPreRelease": true,
      "strategy": {
        "command": {
          "arguments": ["my-command", "--some-option", "foo"]
        }
      }
    }
  }
}
```

> Note: All arguments to custom commands need to be a separate string in the arguments array
> otherwise they may not get passed appropriately to the command, so
> `"my-command --some-option foo"` will likely not work as expected.

#### Pre-Release

Semvar strategies can also include a pre-release strategy that adds a suffix to the semvar version
that can be used. In order for pre-release suffixes to be allowed the `'"allowPreRelease": true'`
must be set on the semvar strategy, you must also supply a pre-release strategy either when calling
the bump-version command or in your configuration.

Currently there are three pre-release strategies, `branch`, `gitTag`, and custom `command`, which we
will discuss.

A pre-release semvar example: `1.0.0-1-8d73287a60`

##### Branch

This will use the branch and optionally short version of the commit sha in order to derive the
pre-release suffix.

```json
{
  "strategy": {
    "semvar": {
      "allowPreRelease": true,
      "preRelease": {
        "strategy": {
          "branch": {
            "includeCommitSha": true
          }
        }
      },
      ...
    }
  }
}
```

This would produce something similar to: `1.0.0-main-8d73287a60`

##### Git Tag

This will use the full output of `git describe --tags` to include the pre-release suffix.

```json
{
  "strategy" : {
    "semvar" : {
      "allowPreRelease" : true,
      "preRelease" : {
        "strategy" : {
          "gitTag" : {}
        }
      },
      ...
    }
  }
}
```

This would produce something similar to: `1.0.0-10-8d73287a60`

##### Custom Command

This allows you to call an external command to generate the pre-release suffix. We will use whatever
the output is as the suffix.

```json
{
  "strategy": {
    "semvar": {
      "allowPreRelease": true,
      "preRelease": {
        "strategy": {
          "command": {
            "arguments": ["my-command", "--some-option", "foo"]
          }
        }
      }
    }
  }
}
```

> Note: All arguments to custom commands need to be a separate string in the arguments array
> otherwise they may not get passed appropriately to the command, so
> `"my-command --some-option foo"` will likely not work as expected.

##### Pre-Release Prefixes

All pre-release strategies can also accept a `prefix` that will appended prior to the generated
pre-release suffix. This can also be used without providing a pre-release strategy to only append
the `prefix` to the semvar.

```json
{
  "strategy" : {
    "semvar" : {
      "allowPreRelease" : true,
      "preRelease" : {
        "prefix": "rc"
      },
      ...
    }
  }
}
```

This would produce something similar to: `1.0.0-rc`
