# ASSUMPTIONS
# * that `npm` cli is present for querying available npm packages

param (
  # used by VerifyPackages
  $artifactLocation, # the root of the artifact folder. DevOps $(System.ArtifactsDirectory)
  $pkgRepository, # used to indicate destination against which we will check the existing version.
  $packagePattern, # the file glob that will be used to collect the packages in the artifact folder. Example: *.whl

  # used by CreateTags
  $releaseSha, # the SHA for the artifacts. DevOps: $(Release.Artifacts.<artifactAlias>.SourceVersion)

  # used by Git Release
  # Expects $env:GH_TOKEN to be populated
  $apiUrl, # API URL for github requests. Example: https://api.github.com/repos/Azure/azure-sdk-for-python
  $targetBranch = "master" # default to master, but should be able to set where the tags end up
)

$VERSION_REGEX = "(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?((?<pre>[^0-9][^\s]+))?"
$SEMVER_REGEX = "^$VERSION_REGEX$"
$TAR_SDIST_PACKAGE_REGEX = "^(?<package>.*)\-(?<versionstring>$VERSION_REGEX$)"

function CreateReleases($pkgList, $releaseApiUrl, $targetBranch)
{
  foreach($pkgInfo in $pkgList)
  {
    Write-Host "Creating release $($pkgInfo.Tag)"
    $url = $releaseApiUrl
    $body = ConvertTo-Json @{
      tag_name = $pkgInfo.Tag
      target_commitish = $targetBranch
      name = $pkgInfo.Tag
      draft = $False
      prerelease = $False
    }
    $headers = @{
      "Content-Type" = "application/json"
      "Authorization" = "token $($env:GH_TOKEN)" 
    }

    try {
      Invoke-RestMethod -Method 'Post' -Uri $url -Body $body -Headers $headers
    }
    catch {
      $statusCode = $_.Exception.Response.StatusCode.value__
      $statusDescription = $_.Exception.Response.StatusDescription
    
      Write-Host "Release request to $releaseApiUrl failed with statuscode $statusCode"
      Write-Host $statusDescription
      exit(1)
    }
  }
}

function ParseMavenPackage($pkg, $artifactLocation)
{
  # todo
}

function IsMavenPackageVersionPublished($pkgId, $pkgVersion)
{
  # todo
}

function ParseNPMPackage($pkg, $artifactLocation)
{
  # prep
  $workFolder = "$artifactLocation/../$($pkg.Basename)"
  $origFolder = Get-Location
  mkdir $workFolder
  cd $workFolder

  # extract, utilize
  tar -xzf $pkg
  $packageJSON = Get-ChildItem -Path $workFolder -Recurse -Include "package.json" | Get-Content | ConvertFrom-Json

  # clean up
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

# checks a package id and version against NPM. If the version already 
# has been published to NPM, return false, else return true 
function IsNPMPackageVersionPublished($pkgId, $pkgVersion)
{
  $npmVersions = (npm show $pkgId versions)

  return $npmVersions.Contains($pkgVersion)

  if ($LastExitCode -ne 0)
  {
    # ensure it isn't a connectivity failure before returning 0.0.0
    npm ping

    if ($LastExitCode -eq 0)
    {
      return $True
    }

    Write-Host "Could not find a deployed version of $pkgId, and NPM connectivity check failed."
    exit(1)
  }

  return $npmVersion
}

function ParseNugetPackage($pkg, $artifactLocation)
{
  # todo
}

function IsNugetPackageVersionPublished($pkgId, $pkgVersion)
{
  # todo
}

# examines a python deployment artifact and greps out the version and id
function ParsePyPIPackage($pkg, $artifactLocation)
{
  $pkg.Basename -match $TAR_SDIST_PACKAGE_REGEX | Out-Null

  $pkgId = $matches['package']
  $pkgVersion = $matches['versionstring']

  return New-Object PSObject -Property @{
    PackageId = $pkgId
    PackageVersion = $pkgVersion
    Deployable = !(IsPythonPackageVersionPublished -pkgId $pkgId -pkgVersion $pkgVersion)
  }
}


# checks a package id and version against PyPI. If the version already 
# has been published to PyPI, return false, else return true 
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
      # so we return a simple version specifier
      return $False
    }

    Write-Host "PyPI Invocation failed:"
    Write-Host "StatusCode:" $statusCode
    Write-Host "StatusDescription:" $statusDescription
    exit(1)
  }
}

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

# walk across all build artifacts, check them against the appropriate repository, return a list of tags/releases
function VerifyPackages($pkgs, $pkgRepository, $artifactLocation, $apiUrl)
{
  $pkgList = [array]@()
  $GetLatestVersionFn = ''
  $ParsePkgInfoFn = ''

  switch($pkgRepository)
  {
    "Maven" {
      $ParsePkgInfoFn = "ParseMavenPackage"
      break
    }
    "Nuget" {
      $ParsePkgInfoFn = "ParseNugetPackage"
      break
    }
    "NPM" {
      $ParsePkgInfoFn = "ParseNPMPackage"
      break
    }
    "PyPI" {
      $ParsePkgInfoFn = "ParsePyPIPackage"
      break
    }
    default { 
      Write-Host "Unrecognized Language: $language"
      exit(1)
    }
  }

  foreach ($pkg in $pkgs)
  {
    try 
    {
      $parsedPackage = &$ParsePkgInfoFn -pkg $pkg -artifactLocation $artifactLocation

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

# VERIFY PACKAGES
$pkgList = VerifyPackages -pkgs (Get-ChildItem $artifactLocation\* -Recurse -File -Include $packagePattern) -pkgRepository $pkgRepository -artifactLocation $artifactLocation -apiUrl $apiUrl

Write-Host "Tags discovered from the artifacts in the artifact directory: "

foreach($packageInfo in $pkgList){
  Write-Host $packageInfo.Tag
}

# CREATE TAGS and RELEASES
CreateReleases -pkgList $pkgList -releaseApiUrl $apiUrl/releases -targetBranch $targetBranch
