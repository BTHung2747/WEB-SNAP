# Read process argv through the public runtime API; no shell evaluation of inputs.
@{args=@([Environment]::GetCommandLineArgs()|Select-Object -Skip 5);cwd=(Get-Location).Path;env=[Environment]::GetEnvironmentVariable('WED_NATIVE_OFFLINE_TEST')}|ConvertTo-Json -Compress -EscapeHandling EscapeNonAscii
