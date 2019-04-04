# ASSUMPTIONS
# * that `npm` cli is present for querying available npm packages
# * that an environment variable $env:GH_TOKEN is populated with the appropriate PAT to allow pushing of github releases

param (
  # used by VerifyPackages
  $artifactLocation, # the root of the artifact folder. DevOps $(System.ArtifactsDirectory)
  $workingDirectory, # directory that package artifacts will be extracted into for examination (if necessary) 
  $packageRepository, # used to indicate destination against which we will check the existing version.
                      # valid options: PyPI, Nuget, NPM, Maven
  # used by CreateTags
  $releaseSha, # the SHA for the artifacts. DevOps: $(Release.Artifacts.<artifactAlias>.SourceVersion)

  # used by Git Release
  $repoOwner, # the owning organization of the repository. EG "Azure"
  $repoName # the name of the repository. EG "azure-sdk-for-java"
)

$VERSION_REGEX = "(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?((?<pre>[^0-9][^\s]+))?"
$SDIST_PACKAGE_REGEX = "^(?<package>.*)\-(?<versionstring>$VERSION_REGEX$)"
$NUGET_PACKAGE_REGEX = "^(?<package>.*?)\.(?<versionstring>(?:\.?[0-9]+){3,}(?:[\-\.\S]+)?)\.nupkg$"
$API_URL = "https://api.github.com/repos/$repoOwner/$repoName"

# Posts a github release for each item of the pkgList variable. SilentlyContinue
function CreateReleases($scriptConfig, $pkgList, $apiUrl, $releaseSha, $workingDirectory)
{
  foreach($pkgInfo in $pkgList)
  {
    Write-Host "Creating release $($pkgInfo.Tag)"
    $url = $apiUrl/releases
    $body = ConvertTo-Json @{
      tag_name = $pkgInfo.Tag
      target_commitish = $releaseSha
      name = $pkgInfo.Tag
      draft = $False
      prerelease = $False
    }
    $headers = @{
      "Content-Type" = "application/json"
      "Authorization" = "token $($env:GH_TOKEN)" 
    }

    try {
      # create the release
      $releaseResults = Invoke-RestMethod -Method 'Post' -Uri $url -Body $body -Headers $headers
      Write-Host $releaseResults

      # upload the artifacts associated with this release
      UploadReleaseArtifacts -scriptConfig $scriptConfig -pkg $pkgInfo -uploadUrlTemplate $releaseResults.upload_url -releaseId $releaseResults.id -workingDirectory $workingDirectory
    }
    catch {
      $statusCode = $_.Exception.Response.StatusCode.value__
      $statusDescription = $_.Exception.Response.StatusDescription
    
      Write-Host "Release request for tag $pkgInfo.Tag failed with statuscode $statusCode."
      Write-Host $statusDescription
      exit(1)
    }
  }
}

# given a release id, upload any package artifacts to it
function UploadReleaseArtifacts($scriptConfig, $pkgInfo, $releaseId, $uploadUrlTemplate, $apiUrl, $workingDirectory)
{
  $destinationZip = $workingDirectory/$pkg
  $assetName = "$($pkgInfo.tag).zip"
  $artifacts = &$scriptConfig.CollectReleaseArtifactsFn

  Compress-Archive -LiteralPath $artifacts -DestinationPath "$workingDirectory/$assetName" -Force

  # by default, upload urls come bacl from the CREATE RELEASE response with a trailer {name, label} to indicate arguments should be placed
  # we need to strip those out and put our own
  $uploadUrl = $uploadUrlTemplate.Replace("{?name,label}", "?name=$assetName")

  # upload the asset, clean up after it's been successfully uploaded
  try {
    IndividualArtifactUpload -uploadUrl $uploadUrl -zip $destinationZip
    Remove-Item $destinationZip -Force -ErrorAction SilentlyContinue
  }
  catch 
  {
    # attempt to delete the release
    CleanupRelease -releaseId $releaseId -apiUrl $apiUrl

    throw $_
  }
}

# attempt to upload an artifact via a POST method. this function retries 3 times prior to exiting
function IndividualArtifactUpload($uploadUrl, $zip)
{
  $tries = 0
  $body = Get-Content $zip
  $headers = @{
    "Content-Type" = "application/zip"
    "Authorization" = "token $($env:GH_TOKEN)" 
  }

  while($tries < 3)
  {
    try 
    {
      Invoke-RestMethod -Method POST -Uri $uploadUrl -Body $body -Headers $headers
    }
    catch 
    {
      if($tries -eq 3)
      {
        Write-Host "Failed repeated attempts to publish individual artifact zip to release. Problem file is $($zip.Name)."
        throw $_
      }
    }
    $tries++
  }
}


# if a given release has failed for any reason, we need to 
function CleanupRelease($releaseId, $apiUrl)
{
  # DELETE /repos/:owner/:repo/releases/:release_id
  # list assets GET /repos/:owner/:repo/releases/:release_id/assets
  try {
    # prior to deleting the release, we need to clean up the 
  }
  catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription
    
    Write-Host "Failure during release cleanup. An earlier error caused the release to only partially complete."
    Write-Host "During attempted cleanup, automation encountered statusCode $statusCode"
    Write-Host $statusDescription
  }
}

function CollectMavenReleaseArtifacts($scriptConfig, $pkgInfo, $workingDirectory)
{
  return Get-ChildItem -Path $pkg.File.Directory.FullName -Include "$($pkgInfo.File.BaseName).*" -File -Recurse
}

# Parse out package publishing information given a maven POM file
function ParseMavenPackage($pkg, $workingDirectory)
{
  [xml]$contentXML = Get-Content $pkg
  
  $pkgId = $contentXML.project.artifactId
  $pkgVersion = $contentXML.project.version
  $groupId = if ($contentXML.project.groupId -eq $null) { $contentXML.project.parent.groupId } else { $contentXML.project.groupId }

  # if it's a snapshot. return $null (as we don't want to create tags for this, but we also don't want to fail)
  if($pkgVersion.Contains("SNAPSHOT")){
    return $null
  }

  return New-Object PSObject -Property @{
    PackageId = $pkgId
    PackageVersion = $pkgVersion
    Deployable = !(IsMavenPackageVersionPublished -pkgId $pkgId -pkgVersion $pkgVersion -groupId $groupId.Replace(".", "/"))
  }
}

# Returns the maven (really sonatype) publish status of a package id and version.
function IsMavenPackageVersionPublished($pkgId, $pkgVersion, $groupId)
{
  try {
    
    $uri = "https://oss.sonatype.org/content/repositories/releases/$groupId/$pkgId/$pkgVersion/$pkgId-$pkgVersion.pom"
    $pomContent = Invoke-RestMethod -Method 'GET' -Uri $uri

    if($pomContent -ne $null -or $pomContent.Length -eq 0)
    {
      return $true
    }
    else 
    {
      return $false
    }
  }
  catch
  {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription
  
    # if this is 404ing, then this pkg has never been published before
    if($statusCode -eq 404)
    {
      return $false
    }

    Write-Host "VersionCheck to maven for packageId $pkgId failed with statuscode $statusCode"
    Write-Host $statusDescription
    exit(1)
  }
}

function CollectNPMReleaseArtifacts($scriptConfig, $pkgInfo, $workingDirectory)
{
  return Get-ChildItem -Path $pkg.File.Directory.FullName -Include "$($pkgInfo.File.BaseName).*" -File -Recurse
}

# Parse out package publishing information given a .tgz npm artifact
function ParseNPMPackage($pkg, $workingDirectory)
{
  $workFolder = "$workingDirectory$($pkg.Basename)"
  $origFolder = Get-Location
  mkdir $workFolder
  cd $workFolder

  tar -xzf $pkg
  $packageJSON = Get-ChildItem -Path $workFolder -Recurse -Include "package.json" | Get-Content | ConvertFrom-Json

  cd $origFolder
  Remove-Item $workFolder -Force  -Recurse -ErrorAction SilentlyContinue

  $pkgId = $packageJSON.name
  $pkgVersion = $packageJSON.version

  return New-Object PSObject -Property @{
    PackageId = $pkgId
    PackageVersion = $pkgVersion
    Deployable = !(IsNPMPackageVersionPublished -pkgId $pkgId -pkgVersion $pkgVersion)
  }
}

# Returns the npm publish status of a package id and version.
function IsNPMPackageVersionPublished($pkgId, $pkgVersion)
{
  $npmVersions = (npm show $pkgId versions)

  if ($LastExitCode -ne 0)
  {
    npm ping

    if ($LastExitCode -eq 0)
    {
      return $True
    }

    Write-Host "Could not find a deployed version of $pkgId, and NPM connectivity check failed."
    exit(1)
  }

  return $npmVersions.Contains($pkgVersion)
}

function CollectNugetReleaseArtifacts($scriptConfig, $pkgInfo, $workingDirectory)
{
  return Get-ChildItem -Path $pkg.File.Directory.FullName -Include "$($pkgInfo.File.BaseName).*" -File -Recurse
}

# Parse out package publishing information given a nupkg ZIP format.
function ParseNugetPackage($pkg, $workingDirectory)
{
  $workFolder = "$workingDirectory$($pkg.Basename)"
  $origFolder = Get-Location
  mkdir $workFolder
  cd $workFolder

  Expand-Archive -Path $pkg -DestinationPath $workFolder
  [xml] $packageXML = Get-ChildItem -Path "$workFolder/*.nuspec" | Get-Content

  cd $origFolder
  Remove-Item $workFolder -Force  -Recurse -ErrorAction SilentlyContinue

  $pkgId = $packageXML.package.metadata.id
  $pkgVersion = $packageXML.package.metadata.version

  return New-Object PSObject -Property @{
    PackageId = $pkgId
    PackageVersion = $pkgVersion
    Deployable = !(IsNugetPackageVersionPublished -pkgId $pkgId -pkgVersion $pkgVersion)
  }
}

# Returns the nuget publish status of a package id and version. 
function IsNugetPackageVersionPublished($pkgId, $pkgVersion)
{

  $nugetUri = "https://api.nuget.org/v3-flatcontainer/$($pkgId.ToLowerInvariant())/index.json"

  try {
    $nugetVersions = Invoke-RestMethod -Method "GET" -Uri $nugetUri

    return $nugetVersions.versions.Contains($pkgVersion)
  }
  catch 
  {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription
    
    # if this is 404ing, then this pkg has never been published before
    if($statusCode -eq 404)
    {
      return $False
    }

    Write-Host "Nuget Invocation failed:"
    Write-Host "StatusCode:" $statusCode
    Write-Host "StatusDescription:" $statusDescription
    exit(1)
  }

}

function CollectPyPIReleaseArtifacts($scriptConfig, $pkgInfo, $workingDirectory)
{
  $originalFile = $pkgInfo.File
  $whlGlob = "$($pkgInfo.PackageId.Replace("-", "_"))-$($pkgInfo.PackageVersion)-*.whl"
  $whlGlob = $pkgInfo.File.BaseName.Replace("_", "-")
  $wheel = Get-ChildItem -Path $pkg.File.Directory.FullName -Include "$whlGlob-*.whl" -File -Recurse

  return @(originalFile, wheel)
}

# Parse out package publishing information given a python sdist of ZIP format.
function ParsePyPIPackage($pkg, $workingDirectory)
{
  $pkg.Basename -match $SDIST_PACKAGE_REGEX | Out-Null

  $pkgId = $matches['package']
  $pkgVersion = $matches['versionstring']

  return New-Object PSObject -Property @{
    PackageId = $pkgId
    PackageVersion = $pkgVersion
    Deployable = !(IsPythonPackageVersionPublished -pkgId $pkgId -pkgVersion $pkgVersion)
  }
}


# Returns the pypi publish status of a package id and version.
function IsPythonPackageVersionPublished($pkgId, $pkgVersion)
{
  try {
    $existingVersion = (Invoke-RestMethod -Method 'Get' -Uri "https://pypi.org/pypi/$pkgId/$pkgVersion/json").info.version

    # if existingVersion exists, then it's already been published
    return $True
  }
  catch 
  {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription
    
    # if this is 404ing, then this pkg has never been published before
    if($statusCode -eq 404)
    {
      return $False
    }

    Write-Host "PyPI Invocation failed:"
    Write-Host "StatusCode:" $statusCode
    Write-Host "StatusDescription:" $statusDescription
    exit(1)
  }
}

# Retrieves the list of all tags that exist on the target repository
function GetExistingTags($apiUrl){
  try {
    return (Invoke-RestMethod -Method 'GET' -Uri "$apiUrl/git/refs/tags"  ) | % { $_.ref.Replace("refs/tags/", "") }
  }
  catch 
  {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription

    Write-Host "Failed to retrieve tags from repository."
    Write-Host "StatusCode:" $statusCode
    Write-Host "StatusDescription:" $statusDescription
    exit(1)
  }
}

# Walk across all build artifacts, check them against the appropriate repository, return a list of tags/releases
function VerifyPackages($scriptConfig, $artifactLocation, $workingDirectory, $apiUrl)
{
  $pkgList = [array]@()
  $pkgs = (Get-ChildItem -Path $artifactLocation -Include $scriptConfig.PackagePattern -Recurse -File) 

  foreach ($pkg in $pkgs)
  {
    try 
    {
      $parsedPackage = &$scriptConfig.ParsePkgInfoFn -pkg $pkg -workingDirectory $workingDirectory

      if($parsedPackage -eq $null){
        continue
      }

      if($parsedPackage.Deployable -ne $True)
      {
        Write-Host "Package $($parsedPackage.PackageId) is marked with version $($parsedPackage.PackageVersion), the version $($parsedPackage.PackageVersion) has already been deployed to the target repository."
        Write-Host "Maybe a pkg version wasn't updated properly?"
        exit(1)
      }

      $pkgList += New-Object PSObject -Property @{
        PackageId = $parsedPackage.PackageId
        PackageVersion = $parsedPackage.PackageVersion
        Tag = ($parsedPackage.PackageId + "_" + $parsedPackage.PackageVersion)
        File = $pkg
      }
    }
    catch 
    {
      Write-Host $_.Exception.Message
      exit(1)
    }
  }

  $results = ([array]$pkgList | Sort-Object -Property Tag -uniq)

  $existingTags = GetExistingTags($apiUrl)
  $intersect = $results | % { $_.Tag } | ?{$existingTags -contains $_}

  if($intersect.Length -gt 0)
  {
    $alreadyExistingTagList = $intersect -Join ", "
    Write-Host "The following tags already exist within the git repo: $alreadyExistingTagList"
    Write-Host "Exiting prior to creation of git releases."
    exit(1)
  }

  Write-Host $results

  return $results
}

function GetConfigurationObject($pkgRepository)
{
  switch($pkgRepository)
  {
    "Maven" {
      return New-Object PSObject -Property @{
        ParsePkgInfoFn = "ParseMavenPackage"
        PackagePattern = "*.pom"
        CollectReleaseArtifactsFn = "CollectMavenReleaseArtifacts"
      }
    }
    "Nuget" {
      return New-Object PSObject -Property @{
        ParsePkgInfoFn = "ParseNugetPackage"
        PackagePattern = "*.nupkg"
        CollectReleaseArtifactsFn = "CollectNugetReleaseArtifacts"
      }
    }
    "NPM" {
      return New-Object PSObject -Property @{
        ParsePkgInfoFn = "ParseNPMPackage"
        PackagePattern = "*.tgz"
        CollectReleaseArtifactsFn = "CollectPyPIReleaseArtifacts"
      }
    }
    "PyPI" {
      return New-Object PSObject -Property @{
        ParsePkgInfoFn = "ParsePyPIPackage"
        PackagePattern = "*.zip"
        CollectReleaseArtifactsFn = "CollectMavenReleaseArtifacts"
      }
    }
    default { 
      Write-Host "Unrecognized Language: $language"
      exit(1)
    }
  }
}

$config = GetConfigurationObject($packageRepository)

# VERIFY PACKAGES
$pkgList = VerifyPackages -scriptConfig $config -artifactLocation $artifactLocation -workingDirectory $workingDirectory -apiUrl $API_URL

Write-Host "Given the visible artifacts, github releases will be created for the following tags:"

foreach($packageInfo in $pkgList){
  Write-Host $packageInfo.Tag
}

# CREATE TAGS and RELEASES
# CreateReleases -scriptConfig $config  -pkgList $pkgList -apiUrl $API_URL -releaseSha $releaseSha -workingDirectory $workingDirectory
