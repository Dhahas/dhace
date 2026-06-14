# Powershell script to run unit tests
Write-Host "Running unit tests..." -ForegroundColor Cyan
zig build test
if ($LASTEXITCODE -eq 0) {
    Write-Host "Success: All tests passed." -ForegroundColor Green
} else {
    Write-Host "Error: Test runner failed." -ForegroundColor Red
    exit $LASTEXITCODE
}
