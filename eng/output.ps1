Write-Host "$(System.ArtifactsDirectory)\_azure-sdk-tools-warden"

$artifactLocation = "$(System.ArtifactsDirectory)\_azure-sdk-tools-warden"
Write-Host $artifactLocation
Write-Host $(PackagePattern)
Write-Host $Host.Version
Write-Host "$artifactLocation/$(PackagePattern)"

$packagePattern = "$(PackagePattern)"

Write-Host "1"
$b = (Get-ChildItem $artifactLocation/* -Recurse -File -Include $(PackagePattern))
Write-Host $b

Write-Host "2"
$c = (Get-ChildItem -Path $artifactLocation -Include $packagePattern -Recurse -File)
Write-Host $c

Write-Host "3"
$d = (Get-ChildItem -Path "$artifactLocation/$packagePattern" -Recurse -File)
Write-Host $d

Write-Host "4"
$e = Get-ChildItem -Path $artifactLocation -Recurse -Include "doc-warden-0.2.3.zip"
Write-Host $e

