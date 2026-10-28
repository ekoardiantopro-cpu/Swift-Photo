$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$workspacePath = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $workspacePath 'assets/branding/swift_photo.png'
$sourceImage = [System.Drawing.Image]::FromFile($sourcePath)
function Write-Icon([string]$destination, [int]$pixels) {
  $bitmap = New-Object System.Drawing.Bitmap($pixels, $pixels, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 255, 253, 242))
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    # Crop a small part of the source padding so the bird fills the launcher
    # tile like modern adaptive icons, while keeping its wing tips in bounds.
    $insetX = [int]($sourceImage.Width * 0.047)
    $insetY = [int]($sourceImage.Height * 0.047)
    $sourceRect = New-Object System.Drawing.Rectangle(
      $insetX,
      $insetY,
      ($sourceImage.Width - (2 * $insetX)),
      ($sourceImage.Height - (2 * $insetY))
    )
    $destinationRect = New-Object System.Drawing.Rectangle(0, 0, $pixels, $pixels)
    $graphics.DrawImage(
      $sourceImage,
      $destinationRect,
      $sourceRect,
      [System.Drawing.GraphicsUnit]::Pixel
    )
    $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Write-AdaptiveIconArt([string]$destination, [int]$pixels) {
  $bitmap = New-Object System.Drawing.Bitmap($pixels, $pixels, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 255, 253, 242))
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    # Android adaptive icons expose only the central safe area of a 108 dp
    # layer. Keep the complete bird inside that area so launcher masks do not
    # crop its wing tips, while matching the visual weight of YouTube's mark.
    $artSize = [int]($pixels * 0.64)
    $offset = [int](($pixels - $artSize) / 2)
    $graphics.DrawImage($sourceImage, $offset, $offset, $artSize, $artSize)
    $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
try {
  $densities = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
  foreach ($density in $densities.Keys) {
    Write-Icon (Join-Path $workspacePath "android/app/src/main/res/mipmap-$density/ic_launcher.png") $densities[$density]
    Write-Icon (Join-Path $workspacePath "android/app/src/main/res/mipmap-$density/ic_launcher_round.png") $densities[$density]
    Write-AdaptiveIconArt (Join-Path $workspacePath "android/app/src/main/res/mipmap-$density/ic_launcher_art.png") $densities[$density]
  }
  # Android 12 masks the startup icon; use a separate padded image so the bird
  # stays inside its safe circle while the launcher artwork remains unchanged.
  $splashDirectory = Join-Path $workspacePath 'android/app/src/main/res/drawable-nodpi'
  New-Item -ItemType Directory -Force $splashDirectory | Out-Null
  $splashBitmap = New-Object System.Drawing.Bitmap(432, 432, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $splashGraphics = [System.Drawing.Graphics]::FromImage($splashBitmap)
  try {
    $splashGraphics.Clear([System.Drawing.Color]::FromArgb(255, 255, 253, 243))
    $splashGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $splashGraphics.DrawImage($sourceImage, 86, 86, 260, 260)
    $splashBitmap.Save((Join-Path $splashDirectory 'splash_logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)
  } finally { $splashGraphics.Dispose(); $splashBitmap.Dispose() }
  $catalogPath = Join-Path $workspacePath 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
  $catalog = Get-Content (Join-Path $catalogPath 'Contents.json') -Raw | ConvertFrom-Json
  foreach ($entry in $catalog.images) {
    if ($entry.filename) {
      $points = [double]::Parse(($entry.size -split 'x')[0], [System.Globalization.CultureInfo]::InvariantCulture)
      $multiplier = [int](($entry.scale -replace 'x', ''))
      Write-Icon (Join-Path $catalogPath $entry.filename) ([int]($points * $multiplier))
    }
  }
} finally { $sourceImage.Dispose() }
Write-Output 'Android and iOS launcher icons packaged.'
