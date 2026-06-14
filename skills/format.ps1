# Powershell script to run zig fmt across all source files
Write-Host "Running Zig Code Formatter..." -ForegroundColor Cyan
zig fmt src/ build.zig
if ($LASTEXITCODE -eq 0) {
    Write-Host "Success: All Zig files formatted correctly." -ForegroundColor Green
} else {
    Write-Host "Error: Code formatting failed." -ForegroundColor Red
    exit $LASTEXITCODE
}
