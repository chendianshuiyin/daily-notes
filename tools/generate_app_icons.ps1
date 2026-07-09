Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$RepoRoot = Split-Path -Parent $PSScriptRoot

function Join-RepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return Join-Path $RepoRoot $RelativePath
}

function New-Color {
    param(
        [Parameter(Mandatory = $true)][string]$Hex,
        [int]$Alpha = 255
    )

    $color = [System.Drawing.ColorTranslator]::FromHtml($Hex)
    return [System.Drawing.Color]::FromArgb($Alpha, $color.R, $color.G, $color.B)
}

function New-RoundedRectanglePath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )

    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Fill-RoundedRectangle {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Graphics]$Graphics,
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius,
        [Parameter(Mandatory = $true)][System.Drawing.Brush]$Brush
    )

    $path = New-RoundedRectanglePath $X $Y $Width $Height $Radius
    try {
        $Graphics.FillPath($Brush, $path)
    } finally {
        $path.Dispose()
    }
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
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        $bounds = [System.Drawing.RectangleF]::new(0, 0, $Size, $Size)
        $background = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $bounds,
            (New-Color '#0f766e'),
            (New-Color '#2563eb'),
            [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
        )
        try {
            $blend = [System.Drawing.Drawing2D.ColorBlend]::new()
            $blend.Positions = [single[]](0, 0.52, 1)
            $blend.Colors = [System.Drawing.Color[]](
                (New-Color '#0f766e'),
                (New-Color '#0891b2'),
                (New-Color '#2563eb')
            )
            $background.InterpolationColors = $blend
            $graphics.FillRectangle($background, $bounds)
        } finally {
            $background.Dispose()
        }

        $highlight = [System.Drawing.SolidBrush]::new((New-Color '#ffffff' 36))
        $warmGlow = [System.Drawing.SolidBrush]::new((New-Color '#fb923c' 46))
        try {
            $graphics.FillEllipse($highlight, -140 * $scale, -174 * $scale, 580 * $scale, 580 * $scale)
            $graphics.FillEllipse($warmGlow, 650 * $scale, 620 * $scale, 540 * $scale, 540 * $scale)
        } finally {
            $highlight.Dispose()
            $warmGlow.Dispose()
        }

        $shadow = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(72, 8, 51, 68))
        $paperBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            [System.Drawing.RectangleF]::new(236 * $scale, 182 * $scale, 552 * $scale, 666 * $scale),
            (New-Color '#fffdf4'),
            (New-Color '#fff7df'),
            [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
        )
        try {
            Fill-RoundedRectangle $graphics (252 * $scale) (210 * $scale) (552 * $scale) (666 * $scale) (56 * $scale) $shadow
            Fill-RoundedRectangle $graphics (236 * $scale) (182 * $scale) (552 * $scale) (666 * $scale) (56 * $scale) $paperBrush
        } finally {
            $shadow.Dispose()
            $paperBrush.Dispose()
        }

        $pagePath = New-RoundedRectanglePath (236 * $scale) (182 * $scale) (552 * $scale) (666 * $scale) (56 * $scale)
        $clipState = $graphics.Save()
        try {
            $graphics.SetClip($pagePath)
            $strip = [System.Drawing.SolidBrush]::new((New-Color '#dff7f1'))
            $fold = [System.Drawing.SolidBrush]::new((New-Color '#ffe3b2'))
            try {
                $graphics.FillRectangle($strip, 236 * $scale, 182 * $scale, 552 * $scale, 130 * $scale)
                $points = [System.Drawing.PointF[]]@(
                    [System.Drawing.PointF]::new(675 * $scale, 182 * $scale),
                    [System.Drawing.PointF]::new(788 * $scale, 295 * $scale),
                    [System.Drawing.PointF]::new(788 * $scale, 182 * $scale)
                )
                $graphics.FillPolygon($fold, $points)
            } finally {
                $strip.Dispose()
                $fold.Dispose()
            }
        } finally {
            $graphics.Restore($clipState)
            $pagePath.Dispose()
        }

        $foldPen = [System.Drawing.Pen]::new((New-Color '#f59e0b'), 12 * $scale)
        $foldPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $foldPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $foldPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        try {
            $graphics.DrawLines($foldPen, [System.Drawing.PointF[]]@(
                [System.Drawing.PointF]::new(675 * $scale, 182 * $scale),
                [System.Drawing.PointF]::new(675 * $scale, 266 * $scale),
                [System.Drawing.PointF]::new(704 * $scale, 295 * $scale),
                [System.Drawing.PointF]::new(788 * $scale, 295 * $scale)
            ))
        } finally {
            $foldPen.Dispose()
        }

        $dotBrush = [System.Drawing.SolidBrush]::new((New-Color '#0f766e'))
        try {
            foreach ($x in @(336, 424, 512)) {
                $graphics.FillEllipse($dotBrush, ($x - 18) * $scale, 231 * $scale, 36 * $scale, 36 * $scale)
            }
        } finally {
            $dotBrush.Dispose()
        }

        $lineColor = New-Color '#0f766e'
        foreach ($line in @(
            @{ X1 = 320; Y = 444; X2 = 704; A = 220 },
            @{ X1 = 320; Y = 537; X2 = 648; A = 178 },
            @{ X1 = 320; Y = 630; X2 = 570; A = 138 }
        )) {
            $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb($line.A, $lineColor.R, $lineColor.G, $lineColor.B), 20 * $scale)
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            try {
                $graphics.DrawLine($pen, $line.X1 * $scale, $line.Y * $scale, $line.X2 * $scale, $line.Y * $scale)
            } finally {
                $pen.Dispose()
            }
        }

        $checkPen = [System.Drawing.Pen]::new((New-Color '#f97316'), 34 * $scale)
        $checkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $checkPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $checkPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        try {
            $graphics.DrawLines($checkPen, [System.Drawing.PointF[]]@(
                [System.Drawing.PointF]::new(584 * $scale, 688 * $scale),
                [System.Drawing.PointF]::new(642 * $scale, 746 * $scale),
                [System.Drawing.PointF]::new(734 * $scale, 626 * $scale)
            ))
        } finally {
            $checkPen.Dispose()
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
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][int]$Size
    )

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
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][int[]]$Sizes
    )

    $path = Join-RepoPath $RelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null

    $images = foreach ($size in $Sizes) {
        [PSCustomObject]@{
            Size = $size
            Data = Get-AppIconPngBytes $size
        }
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
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png' = 16
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png' = 32
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png' = 64
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png' = 128
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png' = 256
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png' = 512
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png' = 1024
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png' = 20
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png' = 40
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png' = 60
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png' = 29
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png' = 58
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png' = 87
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png' = 40
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png' = 80
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png' = 120
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png' = 120
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png' = 180
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png' = 76
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png' = 152
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png' = 167
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png' = 1024
}.GetEnumerator() | ForEach-Object {
    Save-AppIconPng $_.Key $_.Value
}

Save-AppIconIco 'windows/runner/resources/app_icon.ico' @(16, 24, 32, 48, 64, 128, 256)

Write-Host 'Generated Daily Notes app icons.'
