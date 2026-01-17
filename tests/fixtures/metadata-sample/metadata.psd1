@{
    ModuleName = 'metadata-sample'
    Version = '1.0.0'
    Commands = @{
        sample = @{ Handler = 'handler.ps1'; Synopsis = 'Sample handler' }
        route  = @{ Dispatcher = 'Invoke-MetadataSampleDispatcher'; Synopsis = 'Sample dispatcher' }
    }
    Hooks = @{ ModuleLoad = 'Invoke-MetadataSampleLoad' }
}
