param(
    [string]$SourceImage = (Join-Path (Split-Path -Parent $PSScriptRoot) 'BrandLogo.imageset\BrandLogo.png')
)

# Genera las variantes del AppIcon.appiconset y BrandLogo @1x/@2x/@3x
$appIconDir = $PSScriptRoot
$brandDir = (Resolve-Path (Join-Path $appIconDir '..\BrandLogo.imageset')).ProviderPath

if (-not (Test-Path $SourceImage)) {
    $SourceImage = Join-Path $brandDir 'BrandLogo.png'
}

$brandSrc = (Resolve-Path $SourceImage).ProviderPath

Write-Host "Source image:" $brandSrc
Write-Host "AppIcon dir:" $appIconDir
Write-Host "BrandLogo dir:" $brandDir

Add-Type -AssemblyName PresentationCore,WindowsBase

function Resize-And-Save($infile, $outfile, [int]$px) {
    $resolvedIn = (Resolve-Path $infile).ProviderPath
    $resolvedOut = [System.IO.Path]::GetFullPath($outfile)

    if ($resolvedIn -eq $resolvedOut) {
        Write-Host "Skip: misma ruta de origen y destino -> $resolvedOut"
        return
    }

    $fs = [System.IO.File]::OpenRead($resolvedIn)
    try {
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
            $fs,
            [System.Windows.Media.Imaging.BitmapCreateOptions]::IgnoreColorProfile,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        )
        $frame = $decoder.Frames[0]
        $scaleX = $px / $frame.PixelWidth
        $scaleY = $px / $frame.PixelHeight
        $trans = New-Object System.Windows.Media.ScaleTransform($scaleX, $scaleY)
        $tb = New-Object System.Windows.Media.Imaging.TransformedBitmap($frame, $trans)
        $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($tb))
        $outdir = Split-Path $outfile -Parent
        if (-not (Test-Path $outdir)) { New-Item -ItemType Directory -Path $outdir | Out-Null }
        $fsOut = [System.IO.File]::Open($outfile, 'Create')
        try {
            $encoder.Save($fsOut)
        }
        finally {
            $fsOut.Close()
        }
    }
    finally {
        $fs.Close()
    }
}

# 1) Generar BrandLogo@3x (copia), @2x y 1x
$brandOut3 = Join-Path $brandDir 'BrandLogo@3x.png'
$brandOut2 = Join-Path $brandDir 'BrandLogo@2x.png'
$brandOut1 = Join-Path $brandDir 'BrandLogo.png'

Copy-Item -Path $brandSrc -Destination $brandOut3 -Force

$fsTmp = [System.IO.File]::OpenRead($brandSrc)
try {
    $decTmp = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
        $fsTmp,
        [System.Windows.Media.Imaging.BitmapCreateOptions]::IgnoreColorProfile,
        [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    )
    $frameTmp = $decTmp.Frames[0]
    $w = $frameTmp.PixelWidth
}
finally {
    $fsTmp.Close()
}

$px2 = [int]([math]::Round($w * 0.6666666))
$px1 = [int]([math]::Round($w * 0.3333333))

Resize-And-Save $brandSrc $brandOut2 $px2
Resize-And-Save $brandSrc $brandOut1 $px1

Write-Host "Generados BrandLogo: $brandOut1 ($px1 px), $brandOut2 ($px2 px), $brandOut3 ($w px)"

# 2) Generar AppIcon variants según Contents.json
$contentsPath = Join-Path $appIconDir 'Contents.json'
$json = Get-Content $contentsPath -Raw | ConvertFrom-Json

foreach ($img in $json.images) {
    $sizeStr = [string]$img.size
    $sizeVal = [double]($sizeStr -split 'x' | Select-Object -First 1)
    $scaleStr = [string]$img.scale
    $scaleVal = [int]($scaleStr.TrimEnd('x'))
    $px = [int]([math]::Round($sizeVal * $scaleVal))
    $outFile = Join-Path $appIconDir $img.filename
    Resize-And-Save $brandSrc $outFile $px
    Write-Host "Creado: $outFile ($px x $px)"
}

Write-Host "Proceso completado. Revisa $appIconDir y $brandDir"