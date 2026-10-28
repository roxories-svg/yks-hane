$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$sourceApk = Join-Path $projectRoot "web\app-release.apk"
$outputDir = Join-Path $projectRoot "build\web"
$outputApk = Join-Path $outputDir "app-release.apk"

if (-not (Test-Path $sourceApk)) {
    throw "APK bulunamadi: $sourceApk"
}

Push-Location $projectRoot
try {
    flutter build web --release
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter web derlemesi basarisiz oldu."
    }

    if (-not (Test-Path $outputDir)) {
        throw "Flutter cikis klasoru bulunamadi: $outputDir"
    }

    Copy-Item -Path $sourceApk -Destination $outputApk -Force

    $sourceHash = (Get-FileHash $sourceApk -Algorithm SHA256).Hash
    $outputHash = (Get-FileHash $outputApk -Algorithm SHA256).Hash
    if ($sourceHash -ne $outputHash) {
        throw "APK kopyalama dogrulamasi basarisiz oldu."
    }

    firebase deploy --only hosting
    if ($LASTEXITCODE -ne 0) {
        throw "Firebase Hosting deploy islemi basarisiz oldu."
    }
}
finally {
    Pop-Location
}
