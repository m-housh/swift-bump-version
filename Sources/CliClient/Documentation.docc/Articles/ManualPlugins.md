# Manual Plugins

There are two plugins that are included that can be ran manually, if the build tool plugin does not fit
your use case.

## Generate Version

The `generate-version` plugin will create a `Version.swift` file in the given target.  You can
run it by running the following command.

```bash
swift package --disable-sandbox \
  --allow-writing-to-package-directory \
  generate-version \
  <target>
```

> Note: If using the manual version then the `VERSION` variable is an optional string that will be
> `nil`, allowing you to run the `update-version` command in your build pipeline.

## Update Version

The `update-version` plugin can be ran in your build pipeline process to set the version prior to
building for distribution.

```bash
swift package --disable-sandbox \
  --allow-writing-to-package-directory \
  update-version \
  <target>
```

## Options

Both manual versions also allow the following options to customize the operation, the
options need to come after the plugin name.

| Option | Description |
| ------ | ----------- |
| --dry-run | Do not write to any files, but describe where values would be written |
| --filename | Override the file name to be written in the target directory |
| --verbose | Increase the logging output |

### Example with options
```bash
swift package \
  --allow-writing-to-package-directory \
  generate-version \
  --dry-run \
  --verbose \
  <target>
```

## View the Executable Options

You can also run the following command to view the options in your terminal

```bash
swift run cli-version --help
```

Or

```bash
swift run cli-version <verb> --help
```

Where `verb` is one of, `build`, `generate`, or `update`.
