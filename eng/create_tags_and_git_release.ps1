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
$RELEASE_TITLE_REGEX = "(?<releaseNoteTitle>^\#\s.*(?<version>\d+\.\d+\.\d+([^0-9][^\s]+)?))"

# Posts a github release for each item of the pkgList variable. SilentlyContinue
function CreateReleases($pkgList, $releaseApiUrl, $releaseSha)
{
  foreach($pkgInfo in $pkgList)
  {
    Write-Host "Creating release $($pkgInfo.Tag)"

    $releaseNotes = ""
    if ($pkgInfo.ReleaseNotes[$pkgInfo.PackageVersion].ReleaseContent -ne $null) 
    {
      $releaseNotes = $pkgInfo.ReleaseNotes[$pkgInfo.PackageVersion].ReleaseContent 
    }

    $url = $releaseApiUrl
    $body = ConvertTo-Json @{
      tag_name = $pkgInfo.Tag
      target_commitish = $releaseSha
      name = $pkgInfo.Tag
      draft = $False
      prerelease = $False
      body = $releaseNotes
    }

    $headers = @{
      "Content-Type" = "application/json"
      "Authorization" = "token $($env:GH_TOKEN)" 
    }

    PublishRelease -Url $url -Body $body -Headers $headers
  }
}

function PublishRelease($Url, $Body, $Headers)
{
  $attempts = 1
  
  while($attempts -le 3)
  {
    try 
    {
      Invoke-RestMethod -Method "Post" -Uri $Url -Body $Body -Headers $Headers
      break
    }
    catch 
    {
      $response = $_.Exception.Response

      $statusCode = $response.StatusCode.value__
      $statusDescription = $response.StatusDescription
      
      Write-Host "Release request attempt number $attempts to $releaseApiUrl failed with statuscode $statusCode"
      Write-Host $statusDescription

      Write-Host "Rate Limit Details:"
      Write-Host "Total: $($response.Headers.GetValues("X-RateLimit-Limit"))"
      Write-Host "Remaining: $($response.Headers.GetValues("X-RateLimit-Remaining"))"
      Write-Host "Reset Epoch: $($response.Headers.GetValues("X-RateLimit-Reset"))"

      if ($attempts -gt 3)
      {
        Write-Host "Abandoning Release after 3 publish attempts."
        exit(1)
      }

      Start-Sleep -s 10
    }

    $attempts += 1
  }
}

# given a changelog.md file, extract the relevant info we need to decorate a release
function ExtractReleaseNotes($changeLogLocation)
{
  $releaseNotes = @{}
  $contentArrays = @{}
  if ($changeLogLocation.Length -eq 0)
  {
    return $releaseNotes
  }

  try {
    $contents = Get-Content $changeLogLocation

    # walk the document, finding where the version specifiers are and creating lists
    $version = ""
    foreach($line in $contents){
      if ($line -match $RELEASE_TITLE_REGEX)
      {
        $version = $matches["version"]
        $contentArrays[$version] = @()
      }
      
      $contentArrays[$version] += $line
    }

    # resolve each of discovered version specifier string arrays into real content
    foreach($key in $contentArrays.Keys)
    {
      $releaseNotes[$key] = New-Object PSObject -Property @{
        ReleaseVersion = $key
        ReleaseContent = $contentArrays[$key] -join [Environment]::NewLine
      }
    }
  }
  catch
  {
    Write-Host "Error parsing $changeLogLocation."
    Write-Host $_.Exception.Message
  }

  return $releaseNotes
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

  $releaseNotes = ExtractReleaseNotes -changeLogLocation @(Get-ChildItem -Path $pkg.DirectoryName -Recurse -Include "$($pkg.Basename)-changelog.md")[0]

  return New-Object PSObject -Property @{
    PackageId = $pkgId
    PackageVersion = $pkgVersion
    Deployable = !(IsMavenPackageVersionPublished -pkgId $pkgId -pkgVersion $pkgVersion -groupId $groupId.Replace(".", "/"))
    ReleaseNotes = $releaseNotes
  }
}

# Returns the maven (really sonatype) publish status of a package id and version.
function IsMavenPackageVersionPublished($pkgId, $pkgVersion, $groupId)
{
  try {
    
    $uri = "https://oss.sonatype.org/content/repositories/releases/$groupId/$pkgId/$pkgVersion/$pkgId-$pkgVersion.pom"
    $pomContent = Invoke-RestMethod -Method "GET" -Uri $uri

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

# Parse out package publishing information given a .tgz npm artifact
function ParseNPMPackage($pkg, $workingDirectory)
{
  $workFolder = "$workingDirectory$($pkg.Basename)"
  $origFolder = Get-Location
  mkdir $workFolder
  cd $workFolder

  tar -xzf $pkg
  $packageJSON = Get-ChildItem -Path $workFolder -Recurse -Include "package.json" | Get-Content | ConvertFrom-Json
  $releaseNotes = ExtractReleaseNotes -changeLogLocation @(Get-ChildItem -Path $workFolder -Recurse -Include "changelog.md")[0]

  cd $origFolder
  Remove-Item $workFolder -Force  -Recurse -ErrorAction SilentlyContinue


  $pkgId = $packageJSON.name
  $pkgVersion = $packageJSON.version

  return New-Object PSObject -Property @{
    PackageId = $pkgId
    PackageVersion = $pkgVersion
    Deployable = !(IsNPMPackageVersionPublished -pkgId $pkgId -pkgVersion $pkgVersion)
    ReleaseNotes = $releaseNotes
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

# Parse out package publishing information given a nupkg ZIP format.
function ParseNugetPackage($pkg, $workingDirectory)
{
  $workFolder = "$workingDirectory$($pkg.Basename)"
  $origFolder = Get-Location
  $zipFileLocation = "$workFolder/$($pkg.Basename).zip"
  mkdir $workFolder

  Copy-Item -Path $pkg -Destination $zipFileLocation
  Expand-Archive -Path $zipFileLocation -DestinationPath $workFolder
  [xml] $packageXML = Get-ChildItem -Path "$workFolder/*.nuspec" | Get-Content
  $releaseNotes = ExtractReleaseNotes -changeLogLocation @(Get-ChildItem -Path $workFolder -Recurse -Include "changelog.md")[0]

  Remove-Item $workFolder -Force  -Recurse -ErrorAction SilentlyContinue
  $pkgId = $packageXML.package.metadata.id
  $pkgVersion = $packageXML.package.metadata.version

  return New-Object PSObject -Property @{
    PackageId = $pkgId
    PackageVersion = $pkgVersion
    Deployable = !(IsNugetPackageVersionPublished -pkgId $pkgId -pkgVersion $pkgVersion)
    ReleaseNotes = $releaseNotes
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

# Parse out package publishing information given a python sdist of ZIP format.
function ParsePyPIPackage($pkg, $workingDirectory)
{
  $pkg.Basename -match $SDIST_PACKAGE_REGEX | Out-Null

  $pkgId = $matches["package"]
  $pkgVersion = $matches["versionstring"]

  $workFolder = "$workingDirectory$($pkg.Basename)"
  $origFolder = Get-Location
  mkdir $workFolder

  Expand-Archive -Path $pkg -DestinationPath $workFolder
  $releaseNotes = ExtractReleaseNotes -changeLogLocation @(Get-ChildItem -Path $workFolder -Recurse -Include "changelog.md")[0]
  Remove-Item $workFolder -Force  -Recurse -ErrorAction SilentlyContinue

  return New-Object PSObject -Property @{
    PackageId = $pkgId
    PackageVersion = $pkgVersion
    Deployable = !(IsPythonPackageVersionPublished -pkgId $pkgId -pkgVersion $pkgVersion)
    ReleaseNotes = $releaseNotes
  }
}


# Returns the pypi publish status of a package id and version.
function IsPythonPackageVersionPublished($pkgId, $pkgVersion)
{
  try {
    $existingVersion = (Invoke-RestMethod -Method "Get" -Uri "https://pypi.org/pypi/$pkgId/$pkgVersion/json").info.version

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
    return (Invoke-RestMethod -Method "GET" -Uri "$apiUrl/git/refs/tags"  ) | % { $_.ref.Replace("refs/tags/", "") }
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
function VerifyPackages($pkgRepository, $artifactLocation, $workingDirectory, $apiUrl)
{
  $pkgList = [array]@()
  $ParsePkgInfoFn = ""
  $packagePattern = ""

  switch($pkgRepository)
  {
    "Maven" {
      $ParsePkgInfoFn = "ParseMavenPackage"
      $packagePattern = "*.pom"
      break
    }
    "Nuget" {
      $ParsePkgInfoFn = "ParseNugetPackage"
      $packagePattern = "*.nupkg"
      break
    }
    "NPM" {
      $ParsePkgInfoFn = "ParseNPMPackage"
      $packagePattern = "*.tgz"
      break
    }
    "PyPI" {
      $ParsePkgInfoFn = "ParsePyPIPackage"
      $packagePattern = "*.zip"
      break
    }
    default { 
      Write-Host "Unrecognized Language: $language"
      exit(1)
    }
  }

  $pkgs = (Get-ChildItem -Path $artifactLocation -Include $packagePattern -Recurse -File) 

  foreach ($pkg in $pkgs)
  {
    try 
    {
      $parsedPackage = &$ParsePkgInfoFn -pkg $pkg -workingDirectory $workingDirectory

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
        ReleaseNotes = $parsedPackage.ReleaseNotes
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

  return $results
}

$apiUrl = "https://api.github.com/repos/$repoOwner/$repoName"

# VERIFY PACKAGES
$pkgList = VerifyPackages -pkgRepository $packageRepository -artifactLocation $artifactLocation -workingDirectory $workingDirectory -apiUrl $apiUrl

Write-Host "Given the visible artifacts, github releases will be created for the following:"

foreach($packageInfo in $pkgList){
  Write-Host $packageInfo
}

# CREATE TAGS and RELEASES
# CreateReleases -pkgList $pkgList -releaseApiUrl $apiUrl/releases -releaseSha $releaseSha
