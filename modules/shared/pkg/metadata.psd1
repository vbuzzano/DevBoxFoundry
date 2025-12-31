@{
    ModuleName = 'pkg'
    Version = '1.0.0'
    Description = 'Package management module for Boxing'
    Commands = @(
        'install',
        'uninstall',
        'list',
        'validate',
        'state'
    )
    DefaultCommand = 'list'
    RequiredCoreModules = @(
        'ui',
        'config',
        'common'
    )
}
