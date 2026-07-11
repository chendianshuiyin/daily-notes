Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$RepoRoot = Split-Path -Parent $PSScriptRoot

function Join-RepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return Join-Path $RepoRoot $RelativePath
}

function New-Color {
    param([Parameter(Mandatory = $true)][string]$Hex)
    return [System.Drawing.ColorTranslator]::FromHtml($Hex)
}

function New-RoundedRectanglePath {
    param([float]$X, [float]$Y, [float]$Width, [float]$Height, [float]$Radius)

    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-AppIconBitmap {
    param([Parameter(Mandatory = $true)][int]$Size)

    $scale = $Size / 1024.0
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.Clear((New-Color '#f7f8fc'))

        $primary = [System.Drawing.SolidBrush]::new((New-Color '#356ae6'))
        $background = [System.Drawing.SolidBrush]::new((New-Color '#f7f8fc'))
        $accent = [System.Drawing.SolidBrush]::new((New-Color '#f0b429'))
        $white = [System.Drawing.SolidBrush]::new((New-Color '#ffffff'))
        try {
            $bubble = New-RoundedRectanglePath (170 * $scale) (180 * $scale) (678 * $scale) (640 * $scale) (126 * $scale)
            try {
                $graphics.FillPath($primary, $bubble)
            } finally {
                $bubble.Dispose()
            }

            $tail = [System.Drawing.PointF[]]@(
                [System.Drawing.PointF]::new(274 * $scale, 744 * $scale),
                [System.Drawing.PointF]::new(238 * $scale, 878 * $scale),
                [System.Drawing.PointF]::new(430 * $scale, 808 * $scale)
            )
            $graphics.FillPolygon($primary, $tail)

            $cornerCut = [System.Drawing.PointF[]]@(
                [System.Drawing.PointF]::new(688 * $scale, 180 * $scale),
                [System.Drawing.PointF]::new(848 * $scale, 180 * $scale),
                [System.Drawing.PointF]::new(848 * $scale, 348 * $scale)
            )
            $graphics.FillPolygon($background, $cornerCut)
            $fold = [System.Drawing.PointF[]]@(
                [System.Drawing.PointF]::new(688 * $scale, 180 * $scale),
                [System.Drawing.PointF]::new(688 * $scale, 292 * $scale),
                [System.Drawing.PointF]::new(744 * $scale, 348 * $scale),
                [System.Drawing.PointF]::new(848 * $scale, 348 * $scale)
            )
            $graphics.FillPolygon($accent, $fold)

            $graphics.FillEllipse($white, 280 * $scale, 314 * $scale, 52 * $scale, 52 * $scale)
            foreach ($line in @(
                @{ X1 = 374; Y = 340; X2 = 612 },
                @{ X1 = 282; Y = 470; X2 = 738 },
                @{ X1 = 282; Y = 590; X2 = 630 }
            )) {
                $pen = [System.Drawing.Pen]::new((New-Color '#ffffff'), 42 * $scale)
                $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
                try {
                    $graphics.DrawLine($pen, $line.X1 * $scale, $line.Y * $scale, $line.X2 * $scale, $line.Y * $scale)
                } finally {
                    $pen.Dispose()
                }
            }
        } finally {
            $primary.Dispose()
            $background.Dispose()
            $accent.Dispose()
            $white.Dispose()
        }
    } catch {
        $bitmap.Dispose()
        throw
    } finally {
        $graphics.Dispose()
    }
    return $bitmap
}

function Save-AppIconPng {
    param([Parameter(Mandatory = $true)][string]$RelativePath, [Parameter(Mandatory = $true)][int]$Size)
    $path = Join-RepoPath $RelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    $bitmap = New-AppIconBitmap $Size
    try {
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }
}

function Get-AppIconPngBytes {
    param([Parameter(Mandatory = $true)][int]$Size)
    $bitmap = New-AppIconBitmap $Size
    $stream = [System.IO.MemoryStream]::new()
    try {
        $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        return ,$stream.ToArray()
    } finally {
        $stream.Dispose()
        $bitmap.Dispose()
    }
}

function Save-AppIconIco {
    param([Parameter(Mandatory = $true)][string]$RelativePath, [Parameter(Mandatory = $true)][int[]]$Sizes)
    $path = Join-RepoPath $RelativePath
    $images = foreach ($size in $Sizes) {
        [PSCustomObject]@{ Size = $size; Data = Get-AppIconPngBytes $size }
    }
    $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$images.Count)
        $offset = 6 + (16 * $images.Count)
        foreach ($image in $images) {
            $dimension = if ($image.Size -ge 256) { 0 } else { [byte]$image.Size }
            $writer.Write([byte]$dimension)
            $writer.Write([byte]$dimension)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$image.Data.Length)
            $writer.Write([UInt32]$offset)
            $offset += $image.Data.Length
        }
        foreach ($image in $images) {
            $writer.Write([byte[]]$image.Data)
        }
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

Save-AppIconPng 'assets/brand/app_icon_1024.png' 1024

@{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png' = 48
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png' = 72
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png' = 96
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png' = 144
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png' = 192
    'web/favicon.png' = 48
    'web/icons/Icon-192.png' = 192
    'web/icons/Icon-512.png' = 512
    'web/icons/Icon-maskable-192.png' = 192
    'web/icons/Icon-maskable-512.png' = 512
    'linux/runner/resources/app_icon.png' = 256
}.GetEnumerator() | ForEach-Object {
    Save-AppIconPng $_.Key $_.Value
}

Save-AppIconIco 'windows/runner/resources/app_icon.ico' @(16, 24, 32, 48, 64, 128, 256)

Write-Host 'Generated Daily Notes app icons for Android, Web, Windows, and Linux.'
