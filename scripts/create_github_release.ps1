param(
    [string]$Tag = "v1.0.0",
    [string]$Title = "Daily Notes v1.0.0",
    [string]$NotesFile = "docs/github_release_v1.0.0.md"
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
}

Require-Command "gh"
Require-Command "git"

$repoRoot = git rev-parse --show-toplevel
Set-Location $repoRoot

$assets = @(
    "dist/daily-notes-v1.0.0-android-release.apk",
    "dist/daily-notes-v1.0.0-windows-x64.zip",
    "dist/daily-notes-v1.0.0-web.zip"
)

if (-not (Test-Path -LiteralPath $NotesFile)) {
    throw "Release notes file not found: $NotesFile"
}

foreach ($asset in $assets) {
    if (-not (Test-Path -LiteralPath $asset)) {
        throw "Release asset not found: $asset"
    }
}

gh auth status
gh release create $Tag @assets --title $Title --notes-file $NotesFile
