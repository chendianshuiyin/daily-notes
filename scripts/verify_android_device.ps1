[CmdletBinding()]
param(
    [string]$ApkPath = "dist/daily-notes-v1.2.0-android-release.apk",
    [string]$DeviceSerial,
    [string]$SmokeTitle,
    [switch]$AllowEmulator
)

$ErrorActionPreference = "Stop"
$PackageName = "com.chendianshuiyin.dailynotes"

function Resolve-Tool {
    param(
        [string]$Name,
        [string]$Fallback
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    if (Test-Path -LiteralPath $Fallback) {
        return $Fallback
    }
    throw "Missing required tool: $Name"
}

function Invoke-Adb {
    param([string[]]$Arguments)

    $output = & $script:AdbPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb $($Arguments -join ' ') failed:`n$($output -join "`n")"
    }
    return $output
}

function Get-BoundsCenter {
    param([System.Xml.XmlElement]$Node)

    $match = [regex]::Match($Node.bounds, '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$')
    if (-not $match.Success) {
        throw "Invalid UI bounds: $($Node.bounds)"
    }
    $left = [int]$match.Groups[1].Value
    $top = [int]$match.Groups[2].Value
    $right = [int]$match.Groups[3].Value
    $bottom = [int]$match.Groups[4].Value
    return @(
        [int](($left + $right) / 2),
        [int](($top + $bottom) / 2)
    )
}

function Invoke-TapNode {
    param([System.Xml.XmlElement]$Node)

    $center = Get-BoundsCenter $Node
    Invoke-Adb -Arguments @(
        "-s", $script:SelectedSerial, "shell", "input", "tap",
        $center[0].ToString(), $center[1].ToString()
    ) | Out-Null
}

function Get-UiDump {
    param([string]$Name)

    $remotePath = "/sdcard/daily_notes_$Name.xml"
    $localPath = Join-Path $script:EvidenceDir "$Name.xml"
    $dumped = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $output = & $script:AdbPath -s $script:SelectedSerial shell uiautomator dump $remotePath 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dumped = $true
            break
        }
        Start-Sleep -Seconds 1
    }
    if (-not $dumped) {
        throw "Unable to capture Android UI hierarchy: $($output -join "`n")"
    }
    Invoke-Adb -Arguments @("-s", $script:SelectedSerial, "pull", $remotePath, $localPath) | Out-Null
    return [xml](Get-Content -LiteralPath $localPath -Raw -Encoding UTF8)
}

function Save-Screenshot {
    param([string]$Name)

    $path = Join-Path $script:EvidenceDir "$Name.png"
    & $script:AdbPath -s $script:SelectedSerial exec-out screencap -p > $path
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to capture Android screenshot: $Name"
    }
    return $path
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$resolvedApk = if ([System.IO.Path]::IsPathRooted($ApkPath)) {
    (Resolve-Path -LiteralPath $ApkPath).Path
} else {
    (Resolve-Path -LiteralPath (Join-Path $repoRoot $ApkPath)).Path
}

$script:AdbPath = Resolve-Tool "adb" "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$sdkRoot = Split-Path (Split-Path $script:AdbPath -Parent) -Parent
$buildTools = Get-ChildItem (Join-Path $sdkRoot "build-tools") -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1
if (-not $buildTools) {
    throw "Android build-tools are required to inspect the APK."
}
$aaptPath = Join-Path $buildTools.FullName "aapt.exe"

$badging = & $aaptPath dump badging $resolvedApk
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect APK metadata: $resolvedApk"
}
$packageMatch = [regex]::Match(
    ($badging -join "`n"),
    "package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'"
)
if (-not $packageMatch.Success -or $packageMatch.Groups[1].Value -ne $PackageName) {
    throw "Unexpected APK package. Expected $PackageName."
}
$expectedVersionCode = $packageMatch.Groups[2].Value
$expectedVersionName = $packageMatch.Groups[3].Value

$onlineSerials = @(
    Invoke-Adb -Arguments @("devices") |
        ForEach-Object {
            if ($_ -match '^(\S+)\s+device(?:\s|$)') {
                $matches[1]
            }
        }
)
if ($onlineSerials.Count -eq 0) {
    throw "No authorized Android device is connected. Enable USB debugging and accept the RSA prompt."
}

if ($DeviceSerial) {
    if ($DeviceSerial -notin $onlineSerials) {
        throw "Device '$DeviceSerial' is not online. Connected: $($onlineSerials -join ', ')"
    }
    $candidateSerials = @($DeviceSerial)
} else {
    $candidateSerials = $onlineSerials
}

$physicalSerials = @(
    foreach ($serial in $candidateSerials) {
        $isEmulator = (
            Invoke-Adb -Arguments @("-s", $serial, "shell", "getprop", "ro.kernel.qemu") |
                Out-String
        ).Trim() -eq "1"
        if (-not $isEmulator) {
            $serial
        }
    }
)

if ($physicalSerials.Count -eq 1) {
    $script:SelectedSerial = $physicalSerials[0]
} elseif ($physicalSerials.Count -gt 1) {
    throw "Multiple physical devices are connected. Pass -DeviceSerial."
} elseif ($AllowEmulator -and $candidateSerials.Count -eq 1) {
    $script:SelectedSerial = $candidateSerials[0]
} else {
    throw "No physical Android device is connected. Use -AllowEmulator only for script validation."
}

$isSelectedEmulator = (
    Invoke-Adb -Arguments @(
        "-s", $script:SelectedSerial, "shell", "getprop", "ro.kernel.qemu"
    ) | Out-String
).Trim() -eq "1"
if ($isSelectedEmulator -and -not $AllowEmulator) {
    throw "Selected device is an emulator. Physical verification requires real hardware."
}

$evidenceKind = if ($isSelectedEmulator) { "emulator" } else { "physical" }
$serialForPath = $script:SelectedSerial -replace '[^A-Za-z0-9._-]', '_'
$script:EvidenceDir = Join-Path $repoRoot "dist\android-device-verification\$evidenceKind-$serialForPath"
New-Item -ItemType Directory -Path $script:EvidenceDir -Force | Out-Null

Write-Host "Installing $resolvedApk on $($script:SelectedSerial)..."
Invoke-Adb -Arguments @("-s", $script:SelectedSerial, "install", "-r", $resolvedApk) | Write-Host
Invoke-Adb -Arguments @("-s", $script:SelectedSerial, "shell", "am", "force-stop", $PackageName) | Out-Null
Invoke-Adb -Arguments @(
    "-s", $script:SelectedSerial, "shell", "monkey", "-p", $PackageName,
    "-c", "android.intent.category.LAUNCHER", "1"
) | Out-Null
Start-Sleep -Seconds 3

$packageDump = Invoke-Adb -Arguments @(
    "-s", $script:SelectedSerial, "shell", "dumpsys", "package", $PackageName
) | Out-String
$installedVersionName = [regex]::Match($packageDump, 'versionName=([^\s]+)').Groups[1].Value
$installedVersionCode = [regex]::Match($packageDump, 'versionCode=(\d+)').Groups[1].Value
if ($installedVersionName -ne $expectedVersionName -or $installedVersionCode -ne $expectedVersionCode) {
    throw "Installed version mismatch. Expected $expectedVersionName+$expectedVersionCode, got $installedVersionName+$installedVersionCode."
}

$homeXml = Get-UiDump "home-before"
$newNoteNode = $homeXml.SelectSingleNode("//node[@content-desc='新建笔记']")
if (-not $newNoteNode) {
    throw "New note button was not found after launch."
}
Invoke-TapNode $newNoteNode
Start-Sleep -Seconds 1

$editorXml = Get-UiDump "editor-before"
$editFields = @($editorXml.SelectNodes("//node[@class='android.widget.EditText']"))
if ($editFields.Count -lt 3) {
    throw "Expected title, tag, and content fields in the editor."
}

if (-not $SmokeTitle) {
    $SmokeTitle = "device-smoke-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}
if ($SmokeTitle -notmatch '^[A-Za-z0-9._-]+$') {
    throw "SmokeTitle may contain only ASCII letters, numbers, dots, underscores, and hyphens."
}
$smokeBody = "install-save-cold-start-ok"

Invoke-TapNode $editFields[0]
Invoke-Adb -Arguments @(
    "-s", $script:SelectedSerial, "shell", "input", "text", $SmokeTitle
) | Out-Null
Invoke-TapNode $editFields[$editFields.Count - 1]
Invoke-Adb -Arguments @(
    "-s", $script:SelectedSerial, "shell", "input", "text", $smokeBody
) | Out-Null
Start-Sleep -Milliseconds 500

Invoke-Adb -Arguments @(
    "-s", $script:SelectedSerial, "shell", "input", "keyevent", "KEYCODE_BACK"
) | Out-Null
Start-Sleep -Milliseconds 500
$filledEditorXml = Get-UiDump "editor-filled"
$filledTitleNode = $filledEditorXml.SelectSingleNode(
    "//node[@class='android.widget.EditText' and @text='$SmokeTitle']"
)
if (-not $filledTitleNode) {
    throw "Editor closed unexpectedly while hiding the software keyboard."
}
$saveNode = $filledEditorXml.SelectSingleNode("//node[@content-desc='保存']")
if (-not $saveNode) {
    throw "Save button was not found after entering the smoke note."
}
Invoke-TapNode $saveNode
Start-Sleep -Seconds 3

$savedHomeXml = Get-UiDump "home-after-save"
if (
    -not $savedHomeXml.SelectSingleNode("//node[@content-desc='Daily Notes']") -or
    $savedHomeXml.OuterXml -notmatch [regex]::Escape($SmokeTitle)
) {
    throw "Saved smoke note is not visible on Home: $SmokeTitle"
}
Save-Screenshot "home-after-save" | Out-Null

Invoke-Adb -Arguments @("-s", $script:SelectedSerial, "shell", "am", "force-stop", $PackageName) | Out-Null
Invoke-Adb -Arguments @(
    "-s", $script:SelectedSerial, "shell", "monkey", "-p", $PackageName,
    "-c", "android.intent.category.LAUNCHER", "1"
) | Out-Null
Start-Sleep -Seconds 3

$coldStartXml = Get-UiDump "home-cold-start"
if (
    -not $coldStartXml.SelectSingleNode("//node[@content-desc='Daily Notes']") -or
    $coldStartXml.OuterXml -notmatch [regex]::Escape($SmokeTitle)
) {
    throw "Smoke note did not survive a cold start: $SmokeTitle"
}
$screenshotPath = Save-Screenshot "home-cold-start"
$deviceModel = (
    Invoke-Adb -Arguments @(
        "-s", $script:SelectedSerial, "shell", "getprop", "ro.product.model"
    ) | Out-String
).Trim()

[pscustomobject]@{
    Result = "PASS"
    DeviceSerial = $script:SelectedSerial
    DeviceKind = $evidenceKind
    Package = $PackageName
    VersionName = $installedVersionName
    VersionCode = $installedVersionCode
    ApkSha256 = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash
    SmokeTitle = $SmokeTitle
    DeviceModel = $deviceModel
    EvidenceDirectory = $script:EvidenceDir
    Screenshot = $screenshotPath
} | Format-List
