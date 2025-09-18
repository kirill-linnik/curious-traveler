#!/usr/bin/env pwsh
# Post-deployment hook to update mobile app configuration
# Works on Windows, Linux, and Mac with PowerShell Core
Write-Host "Updating mobile app configuration with deployed API URL..."

try {
    # Get the API URL from azd environment (cross-platform JSON parsing)
    $envOutput = azd env get-values --output json
    $envData = $envOutput | ConvertFrom-Json
    $apiUrl = $envData.SERVICE_API_URI

    if ($apiUrl) {
        $configPath = "src/mobile/lib/config/environment_config.dart"
        
        # Check if config file exists
        if (-not (Test-Path $configPath)) {
            Write-Error "Config file not found: $configPath"
            exit 1
        }
        
        # Read the current config file
        $content = Get-Content $configPath -Raw
        
        # Update the production API URL (handle both placeholder and existing URLs)
        $pattern = "('apiBaseUrl': ')https://[^']+(/api')"
        $replacement = "`$1$apiUrl`$2"
        $updatedContent = $content -replace $pattern, $replacement
        
        # Write back to file using UTF-8 encoding (cross-platform compatible)
        $updatedContent | Set-Content $configPath -NoNewline -Encoding UTF8
        
        Write-Host "✓ Updated mobile app configuration with API URL: $apiUrl/api" -ForegroundColor Green
    } else {
        Write-Warning "Could not retrieve SERVICE_API_URI from deployment environment"
        Write-Host "Available environment variables:" -ForegroundColor Yellow
        azd env get-values
        exit 1
    }
} catch {
    Write-Error "Failed to update mobile app configuration: $($_.Exception.Message)"
    exit 1
}