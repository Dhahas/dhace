# Powershell script to compile the application
Write-Host "Compiling Zig Application..." -ForegroundColor Cyan
zig build
if ($LASTEXITCODE -eq 0) {
    Write-Host "Success: Application compiled successfully." -ForegroundColor Green
} else {
    Write-Host "Error: Compilation failed." -ForegroundColor Red
    exit $LASTEXITCODE
}
