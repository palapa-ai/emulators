[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $ArchivePath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string] $Sha256,
    [string] $CoreDirectory = (Join-Path $env:LOCALAPPDATA 'emulators/cores')
)

$ErrorActionPreference = 'Stop'
$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $Sha256) {
    throw 'The core archive checksum does not match.'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    $cores = @($zip.Entries | Where-Object { $_.Name -match '^[a-zA-Z0-9_-]+_libretro\.dll$' })
    if ($cores.Count -ne 1) { throw 'Expected exactly one libretro DLL in the archive.' }
    $entry = $cores[0]
    if ($entry.Length -le 0 -or $entry.Length -gt 64MB) { throw 'Invalid core size.' }
    New-Item -ItemType Directory -Path $CoreDirectory -Force | Out-Null
    $destination = Join-Path (Resolve-Path -LiteralPath $CoreDirectory).Path $entry.Name
    if (Test-Path -LiteralPath $destination) {
        throw "A core already exists at $destination. Move it aside before replacing it."
    }
    # Copy just the named DLL, never extract arbitrary archive paths.
    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination)
    Get-FileHash -LiteralPath $destination -Algorithm SHA256
} finally {
    $zip.Dispose()
}
