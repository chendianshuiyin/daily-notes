param(
    [string]$Tag = "v1.2.0",
    [string]$Title = "Daily Notes v1.2.0",
    [string]$NotesFile = "docs/github_release_v1.2.0.md"
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
}

Require-Command "git"

$ghCommand = Get-Command "gh" -ErrorAction SilentlyContinue
if (-not $ghCommand) {
    $fallbackGh = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path -LiteralPath $fallbackGh) {
        $ghPath = $fallbackGh
    } else {
        throw "Missing required command: gh"
    }
} else {
    $ghPath = $ghCommand.Source
}

$repoRoot = git rev-parse --show-toplevel
Set-Location $repoRoot

$assets = @(
    "dist/daily-notes-$Tag-android-release.apk",
    "dist/daily-notes-$Tag-web.zip"
)

if (-not (Test-Path -LiteralPath $NotesFile)) {
    throw "Release notes file not found: $NotesFile"
}

foreach ($asset in $assets) {
    if (-not (Test-Path -LiteralPath $asset)) {
        throw "Release asset not found: $asset"
    }
}

& $ghPath auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}

& $ghPath release create $Tag @assets --title $Title --notes-file $NotesFile
if ($LASTEXITCODE -ne 0) {
    throw "GitHub Release creation failed."
}
