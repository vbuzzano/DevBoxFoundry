# Module discovery v2 fixtures

These fixtures support external module and metadata scenarios for Pester tests.

## External single-file
- `external-single/hello.ps1` — simple script that echoes arguments as `hello:<args>`.

## External directory module
- `external-dir/foo/foo.ps1` — default command, returns `foo-default` plus args.
- `external-dir/foo/bar.ps1` — subcommand, returns `foo-bar` plus args.

## Metadata sample module
- `metadata-sample/metadata.psd1` — declares handler and dispatcher commands.
- `metadata-sample/handler.ps1` — returns `handler:<args>`.
- `metadata-sample/dispatcher.ps1` — dispatcher `Invoke-MetadataSampleDispatcher` plus load hook `Invoke-MetadataSampleLoad`.
- `metadata-sample/help.ps1` — custom help output.

Usage: copy or point tests to these fixtures to validate discovery, routing, help, and argument passthrough behaviors.
