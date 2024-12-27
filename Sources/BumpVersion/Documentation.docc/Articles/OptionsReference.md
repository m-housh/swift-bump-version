# Options Reference

Common options used for the commands.

## Overview

The commands mostly all accept similar options, below is a list of those options and a description
of their usage.

### General Options

| Short | Long                | Argument | Description                                                          |
| ----- | ------------------- | -------- | -------------------------------------------------------------------- |
| N/A   | --print             | N/A      | Perform the command, but don't write any output files                |
| N/A   | --project-directory | <path>   | The path to the root of your project, defaults to current directory  |
| -h    | --help              | N/A      | Show help for a command                                              |
| -v    | --verbose           | N/A      | Increase logging level, can be passed multiple times (example: -vvv) |
| N/A   | --version           | N/A      | Show the version of the command line tool                            |

### Configuration Options

| Short | Long                               | Argument    | Description                                                                        |
| ----- | ---------------------------------- | ----------- | ---------------------------------------------------------------------------------- |
| -f    | --configuration-file               | <path>      | The path to the configuration to use.                                              |
| -m    | --target-module                    | <name>      | The target module name inside your project                                         |
| -n    | --target-file-name                 | <name>      | The file name for the version to be found inside the module                        |
| -p    | --target-file-path                 | <path>      | Path to a version file in your project                                             |
| N/A   | --enable-git-tag/--disable-git-tag | N/A         | Use the git-tag version strategy                                                   |
| N/A   | --require-exact-match              | N/A         | Fail if a tag is not specifically set on the commit                                |
| N/A   | --require-existing-semvar          | N/A         | Fail if an existing semvar is not found in the version file.                       |
| -c    | --custom-command                   | <arguments> | Use a custom command strategy for the version (any options need to proceed a '--') |
| N/A   | --commit-sha/--no-commit-sha       | N/A         | Use the commit sha with branch version or pre-release strategy                     |
| N/A   | --require-configuration            | N/A         | Fail if a configuration file is not found                                          |

#### Pre-Release Options

| Short | Long                         | Argument    | Description                                                  |
| ----- | ---------------------------- | ----------- | ------------------------------------------------------------ |
| -d    | --disable-pre-release        | N/A         | Disable pre-relase suffixes from being used                  |
| -b    | --pre-release-branch-style   | N/A         | Use the branch and commit sha style for pre-release suffixes |
| N/A   | --commit-sha/--no-commit-sha | N/A         | Use the commit sha with branch pre-release strategy          |
| -g    | --pre-release-git-tag-style  | N/A         | Use the git tag style for pre-release suffixes               |
| N/A   | --pre-release-prefix         | <prefix>    | A prefix to use before a pre-release suffix                  |
| N/A   | --custom-pre-release         | <arguments> | Use custom command strategy for pre-release suffix           |

> Note: When using one of the `--custom-*` options then any arguments passed will be used for
> arguments when calling your custom strategy, if the external tool you use requires options they
> must proceed a '--' otherwise you will get an error that an 'unexpected option' is being used.
