# Draws tri-design.ico: a blue rounded square with three white steps (the three design stages), so the
# shortcut doesn't look like Claude's orange icon. PNG-compressed ICO with 16-256 px images.
Add-Type -AssemblyName System.Drawing
$out = Join-Path $PSScriptRoot 'tri-design.ico'

function New-IconPng([int]$Size) {
    $bmp = [Drawing.Bitmap]::new($Size, $Size)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.Clear([Drawing.Color]::Transparent)
    $r = [single]($Size * 0.22); $d = $r * 2; $m = [single]([Math]::Max(1, $Size * 0.03)); $w = $Size - 2 * $m
    $bg = [Drawing.Drawing2D.GraphicsPath]::new()
    $bg.AddArc($m, $m, $d, $d, 180, 90); $bg.AddArc($m + $w - $d, $m, $d, $d, 270, 90)
    $bg.AddArc($m + $w - $d, $m + $w - $d, $d, $d, 0, 90); $bg.AddArc($m, $m + $w - $d, $d, $d, 90, 90); $bg.CloseFigure()
    $grad = [Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.PointF]::new(0, 0), [Drawing.PointF]::new($Size, $Size),
        [Drawing.Color]::FromArgb(59, 130, 246), [Drawing.Color]::FromArgb(29, 78, 216))
    $g.FillPath($grad, $bg)
    # three steps rising left to right
    $white = [Drawing.SolidBrush]::new([Drawing.Color]::White)
    $base = $Size * 0.76; $barW = $Size * 0.17; $gap = $Size * 0.06; $left = ($Size - (3 * $barW + 2 * $gap)) / 2
    foreach ($i in 0..2) {
        $h = $Size * (0.20 + 0.17 * $i)
        $g.FillRectangle($white, [single]($left + $i * ($barW + $gap)), [single]($base - $h), [single]$barW, [single]$h)
    }
    $g.Dispose()
    $ms = [IO.MemoryStream]::new(); $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    , $ms.ToArray()
}

$sizes = 16, 24, 32, 48, 64, 128, 256
$pngs = foreach ($s in $sizes) { , (New-IconPng $s) }
$fs = [IO.File]::Create($out); $bw = [IO.BinaryWriter]::new($fs)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $len = $pngs[$i].Length
    $bw.Write([byte]($s % 256)); $bw.Write([byte]($s % 256)); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$len); $bw.Write([uint32]$offset)
    $offset += $len
}
foreach ($p in $pngs) { $bw.Write($p) }
$bw.Close()
"已生成：$out"
