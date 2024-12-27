# Command Reference

Learn about the provided commands.

## Overview

The command-line tool provides the following commands.

> See Also:
>
> 1. <doc:BasicConfiguration>
> 1. <doc:ConfigurationReference>

All commands output the path of the file they generate or write to, to allow them to be piped into
other commands, however this will not work if you specify `--verbose` because then other output is
also written to `stdout`.

### Bump Command

This bumps the version to the next version based on the project configuration or passed in options.
This is the default command when calling the `bump-version` tool, so specifying the `bump` command
is not required, but will be shown in examples below for clarity.

> See Also: <doc:OptionsReference>

The following options are used to declare which part of a semvar to bump to the next version, they
are ignored if your configuration or options specify to use a `branch` strategy.

| Long          | Description                             |
| ------------- | --------------------------------------- |
| --major       | Bump the major portion of the semvar    |
| --minor       | Bump the minor portion of the semvar    |
| --patch       | Bump the patch portion of the semvar    |
| --pre-release | Bump the pre-release suffix of a semvar |

#### Bump Command Usage Examples

```bash
bump-version bump --minor
```

Show the output, but don't update the version file.

```bash
bump-version bump --major --dry-run
```

### Generate Command

This generates a version file based on your configuration, setting it's initial value based on your
projects configuration strategy. This is generally only ran once after setting up a project.

```bash
bump-version generate
```

### Configuration Commands

The following commands are used to work with project configuration.

#### Generate Command

Generates a configuration file based on the passed in options.

> See Also: <doc:OptionsReference>

The following options are used to declare strategy used for deriving the version.

| Long     | Description                                             |
| -------- | ------------------------------------------------------- |
| --branch | Use the branch strategy                                 |
| --semvar | Use the semvar strategy (default)                       |
| --print  | Print the output to stdout instead of generating a file |

##### Generate Configuration Example

```bash
bump-version config generate -m my-tool
```

The above generates a configuration file using the default version strategy for a target module
named 'my-tool'.

#### Dump Command

Dumps the parsed configuration to `stdout`.

> See Also: <doc:OptionsReference>

The following options are used to declare what output gets printed.

| Long    | Description          |
| ------- | -------------------- |
| --json  | Print json (default) |
| --swift | Print swift struct   |

##### Dump Configuration Example

```bash
bump-version config dump --disable-pre-release
```

This command can also be used to extend a configuration file with new configuration by sending the
output to a new file.

```bash
bump-version config dump --disable-pre-release > .bump-version.prod.json
```
