<#
.SYNOPSIS
    Builds the Flutter Release APK for Laundry Management with required Supabase configuration.

.DESCRIPTION
    In Release mode (kReleaseMode == true), SupabaseConfig strictly enforces compile-time environment
    variables (SUPABASE_URL_ROOT and SUPABASE_ANON_KEY) to prevent accidental fallback to development
    credentials (RISK-002). This script ensures the required --dart-define flags are supplied.

.PARAMETER SupabaseUrlRoot
    The Supabase project root URL (e.g., https://<project-ref>.supabase.co).
    Defaults to $env:SUPABASE_URL_ROOT if set.

.PARAMETER SupabaseAnonKey
    The Supabase public anonymous API key.
    Defaults to $env:SUPABASE_ANON_KEY if set.

.PARAMETER DefineFile
    Optional path to a JSON configuration file formatted for --dart-define-from-file.

.EXAMPLE
    .\scripts\build_release.ps1 -SupabaseUrlRoot "https://xyz.supabase.co" -SupabaseAnonKey "eyJ..."
    .\scripts\build_release.ps1 -DefineFile "scripts/release_env.json"
#>

[CmdletBinding()]
param(
    [string]$SupabaseUrlRoot = $env:SUPABASE_URL_ROOT,
    [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY,
    [string]$DefineFile = ""
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
Set-Location $workspaceRoot

if ($DefineFile -ne "") {
    if (-not (Test-Path $DefineFile)) {
        Write-Error "Define file not found: $DefineFile"
        exit 1
    }
    $fileContent = Get-Content -Raw $DefineFile
    if ($fileContent -match "dyhfgnbhijukbdptreto") {
        Write-Error "Safety check failed: Define file '$DefineFile' targets the Development Supabase project ('dyhfgnbhijukbdptreto'). Release builds must target Production ('rvrskluqfbrkvvlxtxfp')."
        exit 1
    }
    if ($fileContent -match "<.*>" -or $fileContent -match "REPLACE_WITH_PRODUCTION_ANON_KEY") {
        Write-Error "Safety check failed: Define file '$DefineFile' contains unreplaced placeholders. Provide your actual Production Supabase anon key."
        exit 1
    }
    Write-Host "Building release APK using define file: $DefineFile" -ForegroundColor Cyan
    flutter build apk --release --dart-define-from-file="$DefineFile"
} else {
    if ([string]::IsNullOrWhiteSpace($SupabaseUrlRoot) -or [string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
        Write-Error @"
Missing required Supabase configuration for release build.
In release mode, SupabaseConfig strictly forbids falling back to development credentials.

Please supply parameters or set environment variables:
  .\scripts\build_release.ps1 -SupabaseUrlRoot "https://rvrskluqfbrkvvlxtxfp.supabase.co" -SupabaseAnonKey "<your-production-anon-key>"
Or:
  `$env:SUPABASE_URL_ROOT = "https://rvrskluqfbrkvvlxtxfp.supabase.co"
  `$env:SUPABASE_ANON_KEY = "<your-production-anon-key>"
  .\scripts\build_release.ps1
Or supply a define file:
  .\scripts\build_release.ps1 -DefineFile "scripts/release_env.json"
"@
        exit 1
    }

    if ($SupabaseUrlRoot -match "dyhfgnbhijukbdptreto") {
        Write-Error "Safety check failed: SupabaseUrlRoot targets the Development Supabase project ('dyhfgnbhijukbdptreto'). Release builds must target Production ('rvrskluqfbrkvvlxtxfp')."
        exit 1
    }

    if ($SupabaseAnonKey -match "<.*>" -or $SupabaseAnonKey -match "REPLACE_WITH_PRODUCTION_ANON_KEY") {
        Write-Error "Safety check failed: SupabaseAnonKey contains placeholder text. Provide your actual Production Supabase anon key."
        exit 1
    }

    Write-Host "Building release APK with explicit --dart-define parameters..." -ForegroundColor Cyan
    flutter build apk --release `
        --dart-define="SUPABASE_URL_ROOT=$SupabaseUrlRoot" `
        --dart-define="SUPABASE_ANON_KEY=$SupabaseAnonKey"
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nRelease APK build successful: build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Green
} else {
    Write-Error "flutter build apk --release failed with exit code $LASTEXITCODE"
}
