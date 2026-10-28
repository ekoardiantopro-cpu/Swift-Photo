$ErrorActionPreference = 'Stop'
$developerRoot = Join-Path $env:USERPROFILE 'develop'
$androidRoot = Join-Path $env:LOCALAPPDATA 'SwiftOSAndroid'
$flutterCommand = Join-Path $developerRoot 'flutter\bin\flutter.bat'
if (!(Test-Path -LiteralPath $flutterCommand)) {
    throw "Flutter SDK tidak ditemukan: $flutterCommand"
}
$env:PATH = "$developerRoot\mingit\cmd;$developerRoot\flutter\bin;$env:PATH"
$env:ANDROID_HOME = Join-Path $androidRoot 'sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$javaDirectory = Get-ChildItem (Join-Path $androidRoot 'java') -Directory |
    Where-Object Name -Like 'jdk-*' | Sort-Object Name -Descending | Select-Object -First 1
if ($javaDirectory) {
    $env:JAVA_HOME = $javaDirectory.FullName
    $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
}
& $flutterCommand @args
exit $LASTEXITCODE
