param(
  [string]$Alias = 'swift-photo'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$androidRoot = Join-Path $projectRoot 'android'
$keyStorePath = Join-Path $androidRoot 'app\swift-photo-release.jks'
$propertiesPath = Join-Path $androidRoot 'key.properties'

if (Test-Path -LiteralPath $keyStorePath) {
  throw "Keystore sudah ada: $keyStorePath. Jangan ditimpa; file ini menentukan identitas update aplikasi."
}
if (Test-Path -LiteralPath $propertiesPath) {
  throw "key.properties sudah ada: $propertiesPath. Periksa file sebelum membuat keystore baru."
}

$keytool = (Get-Command keytool.exe -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
  $bundled = 'C:\Users\USER\AppData\Local\SwiftOSAndroid\java\jdk-17.0.20.1+1\bin\keytool.exe'
  if (Test-Path -LiteralPath $bundled) { $keytool = $bundled }
}
if (-not $keytool) {
  throw 'keytool.exe tidak ditemukan. Pasang JDK 17 atau tambahkan folder bin JDK ke PATH.'
}

function ConvertTo-PlainText([Security.SecureString]$value) {
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($value)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
  }
}

$first = Read-Host 'Buat password keystore (minimal 12 karakter)' -AsSecureString
$second = Read-Host 'Ulangi password' -AsSecureString
$password = ConvertTo-PlainText $first
$confirmation = ConvertTo-PlainText $second
try {
  if ($password.Length -lt 12) { throw 'Password harus minimal 12 karakter.' }
  if ($password -cne $confirmation) { throw 'Password tidak sama.' }

  & $keytool -genkeypair -v `
    -keystore $keyStorePath `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias $Alias `
    -dname 'CN=Swift Photo, OU=Mobile, O=Swift Photo, C=ID' `
    -storepass $password `
    -keypass $password
  if ($LASTEXITCODE -ne 0) { throw 'keytool gagal membuat keystore.' }

  @(
    "storePassword=$password"
    "keyPassword=$password"
    "keyAlias=$Alias"
    'storeFile=swift-photo-release.jks'
  ) | Set-Content -LiteralPath $propertiesPath -Encoding Ascii

  Write-Host ''
  Write-Host 'Keystore release berhasil dibuat.' -ForegroundColor Green
  Write-Host "Cadangkan file ini di tempat aman: $keyStorePath"
  Write-Host 'Jangan commit keystore atau key.properties ke Git.'
} finally {
  $password = $null
  $confirmation = $null
}
