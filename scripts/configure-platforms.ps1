$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$androidManifest = Join-Path $projectRoot 'android\app\src\main\AndroidManifest.xml'
if (!(Test-Path -LiteralPath $androidManifest)) {
    throw 'Jalankan Flutter create terlebih dahulu.'
}
$androidNamespace = 'http://schemas.android.com/apk/res/android'
$document = [xml](Get-Content -LiteralPath $androidManifest -Raw)
$manifest = $document.DocumentElement
$manifest.SetAttribute('xmlns:tools', 'http://schemas.android.com/tools')
$permissions = @(
    'android.permission.INTERNET',
    'android.permission.CAMERA',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.WRITE_EXTERNAL_STORAGE'
)
foreach ($permission in $permissions) {
    $node = @($manifest.SelectNodes('uses-permission')) | Where-Object {
        $_.GetAttribute('name', $androidNamespace) -eq $permission
    } | Select-Object -First 1
    if (!$node) {
        $node = $document.CreateElement('uses-permission')
        $node.SetAttribute('name', $androidNamespace, $permission) | Out-Null
        $manifest.PrependChild($node) | Out-Null
    }
    if ($permission -eq 'android.permission.WRITE_EXTERNAL_STORAGE') {
        $node.SetAttribute('maxSdkVersion', $androidNamespace, '29') | Out-Null
        $node.SetAttribute('replace', 'http://schemas.android.com/tools', 'android:maxSdkVersion') | Out-Null
    }
}
$manifest.SelectSingleNode('application').SetAttribute('label', $androidNamespace, 'Swift Photo') | Out-Null
$document.Save($androidManifest)

$gradlePath = Join-Path $projectRoot 'android\app\build.gradle.kts'
if (Test-Path -LiteralPath $gradlePath) {
    $gradle = Get-Content -LiteralPath $gradlePath -Raw
    $gradle = $gradle -replace 'minSdk\s*=\s*flutter.minSdkVersion', 'minSdk = 24'
    [IO.File]::WriteAllText($gradlePath, $gradle, [Text.UTF8Encoding]::new($false))
}

$plistPath = Join-Path $projectRoot 'ios\Runner\Info.plist'
if (Test-Path -LiteralPath $plistPath) {
    $plist = [xml](Get-Content -LiteralPath $plistPath -Raw)
    $dictionary = $plist.SelectSingleNode('/plist/dict')
    $values = @{
        CFBundleDisplayName = 'Swift Photo'
        NSCameraUsageDescription = 'Kamera digunakan untuk mengambil foto dokumentasi.'
        NSPhotoLibraryAddUsageDescription = 'Swift Photo menyimpan foto berwatermark ke galeri.'
        NSPhotoLibraryUsageDescription = 'Pilih logo perusahaan dari galeri.'
        NSLocationWhenInUseUsageDescription = 'Lokasi digunakan untuk watermark koordinat dan alamat.'
    }
    foreach ($key in $values.Keys) {
        $keyNode = @($dictionary.SelectNodes('key')) | Where-Object InnerText -EQ $key | Select-Object -First 1
        if ($keyNode) {
            $keyNode.NextSibling.InnerText = $values[$key]
        } else {
            $keyNode = $plist.CreateElement('key')
            $keyNode.InnerText = $key
            $valueNode = $plist.CreateElement('string')
            $valueNode.InnerText = $values[$key]
            $dictionary.AppendChild($keyNode) | Out-Null
            $dictionary.AppendChild($valueNode) | Out-Null
        }
    }
    $plist.Save($plistPath)
}
Write-Output 'Konfigurasi izin Android/iOS Swift Photo selesai.'
