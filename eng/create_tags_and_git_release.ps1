param (
  # used by VerifyPackages
  $artifactLocation, # the root of the artifact folder. DevOps $(System.ArtifactsDirectory)
  $pkgRepository, # used to indicate destination against which we will check the existing version.

  # used by CreateTags
  $releaseSha, # the SHA for the artifacts. DevOps: $(Release.Artifacts.<artifactAlias>.SourceVersion)

  # used by Git Release
  # Expects $env:GH_TOKEN to be populated
  $apiUrl, # API URL for github requests
  $targetBranch = "master" # default to master, but should be able to set where the tags end up
)

function CreateTags($pkgList, $apiUrl, $releaseSha)
{
  # common headers. don't need to define multiple times
  $headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "token $($env:GH_TOKEN)" 
  }

  foreach($pkgInfo in $pkgList){
    Write-Host "Writing $($pkgInfo.Tag)"

    try {
      $tagObjectBody = ConvertTo-Json @{
        tag = $pkgInfo.Tag
        message = "$($pkgInfo.PackageVersion) release of $($pkgInfo.PackageId)"
        object = $releaseSha
        type = "commit"
        tagger = @{
          name = "Azure SDK Engineering System"
          email = "azuresdkeng@microsoft.com"
          date = Get-Date -Format "o"
        }
      }

      $outputSHA = (Invoke-RestMethod -Method 'Post' -Uri $apiUrl/git/tags -Body $tagObjectBody -Headers $headers).sha

      $refObjectBody = ConvertTo-Json @{
        "ref" = "refs/tags/$($pkgInfo.Tag)"
        "sha" = $outputSHA
      }

      $result = (Invoke-RestMethod -Method 'Post' -Uri $apiUrl/git/refs -Body $refObjectBody -Headers $headers)
    }
    catch 
    {
      $statusCode = $_.Exception.Response.StatusCode.value__
      $statusDescription = $_.Exception.Response.StatusDescription

      Write-Host "Tag creation failed with statuscode $statusCode. Reason: "
      Write-Host $statusDescription
      exit(1)
    }
  }
}

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

function ToSemVer($version)
{
  $version -match "^(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?((?<pre>[A-Za-z\-\.][0-9A-Za-z]+))?$" | Out-Null
  $major = [int]$matches['major']
  $minor = [int]$matches['minor']
  $patch = [int]$matches['patch']
  
  if($matches['pre'] -eq $null)
  {
    $pre = "0"
  }
  else
  {
    $pre = $matches['pre']
  }

  New-Object PSObject -Property @{
    Major = $major
    Minor = $minor
    Patch = $patch
    Pre = $pre
    VersionString = $version
    }
}

# compares two SemVer objects
# if $a is bigger, return -1
# if $b is bigger, return 1
# else return 0
function CompareSemVer($a, $b)
{
  $result = 0

  $result =  $a.Major.CompareTo($b.Major)
  if($result -ne 0)
  {
    return $result
  }

  $result = $a.Minor.CompareTo($b.Minor)
  if($result -ne 0)
  {
    return $result
  }

  # compare the patch before the preview identifiers
  $result = $a.Patch.CompareTo($b.Patch)
  if($result -ne 0)
  {
    return $result
  }

  # if they have 0 length, they are equivalent
  if($a.Pre.Length -eq 0 -and $b.Pre.Length -eq 0) 
  {
    return 0
  }
  
  # a is blank and b is not? b is greater
  if($a.Pre.Length -eq 0)
  {
    return 1
  }
  
  if($b.Pre.Length -eq 0){
    return -1
  }
  
  $ac = $a.Pre[$i]
  $bc = $b.Pre[$i]

  $anum = 0 
  $bnum = 0
  $aIsNum = [Int]::TryParse($ac, [ref] $anum)
  $bIsNum = [Int]::TryParse($bc, [ref] $bnum)

  if($aIsNum -and $bIsNum) 
  { 
      $result = $anum.CompareTo($bnum) 
      if($result -ne 0)
      {
          return $result
      }
  }

  if($aIsNum)
  {
      return -1
  }

  if($bIsNum)
  {
    return 1
  }
  
  $result = [string]::CompareOrdinal($ac, $bc)
  if($result -ne 0)
  {
    return $result
  }

  Write-Host "We are here, which means that we haven't returned yet"
  return $a.Pre.Length.CompareTo($b.Pre.Length)
}

function ParseMavenPackage($pkg)
{
  # todo
}

function InvokeMaven($pkgId)
{
  # todo
}

function ParseNPMPackage($pkg)
{
  # todo
}

function InvokeNPM($pkgId)
{
  # todo
}

function ParseNugetPackage($pkg)
{
  # todo
}

function InvokeNuget($pkgId)
{
  # todo
}

# examines a python deployment artifact and greps out the version and id
function ParsePyPIPackage($pkg)
{
  $extension = $pkg.Extension
  $pkgId = ''
  $pkgVersion = ''

  if($pkg.Extension -eq ".whl")
  {
    $nameParts = $pkg.Basename -Split "-"

    $pkgId = $nameParts[0].Replace("_", "-")
    $pkgVersion = $nameParts[1]
  }
  else {
    if($pkg.Extension -eq ".zip")
    {
      $nameParts = $pkg.Basename -Split "-"

      $pkgId = $nameParts[0..($nameParts.Length - 2)] -join "-"
      $pkgVersion = $nameParts[($nameParts.Length-1)]
    }
    else {
      Write-Host "Not a recognized pkg type: $extension"
      exit(1)
    }  
  }

  return New-Object PSObject -Property @{
    PackageId = $pkgId
    PackageVersion = $pkgVersion
    PackageSemVer = ToSemVer $pkgVersion
    PublishedSemVer = ToSemVer (InvokePyPI -pkgId $pkgId)
  }
}

# invokes PYPI, returns the existing version of a pkg.
# if it can't find that pkg, returns version 0.0.0
function InvokePyPI($pkgId)
{
  try {
    return (Invoke-RestMethod -Method 'Get' -Uri "https://pypi.org/pypi/$pkgId/json").info.version
  }
  catch 
  {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription
    
    # if this is 404ing, then this pkg has never been published before
    if($statusCode -eq 404)
    {
      # so we return a simple version specifier
      return "0.0.0"
    }

    Write-Host "PyPI Invocation failed:"
    Write-Host "StatusCode:" $statusCode
    Write-Host "StatusDescription:" $statusDescription
    exit(1)
  }
}

# walk across all build artifacts, check them against the appropriate repository, return a list of tags/releases
function VerifyPackages($pkgs, $pkgRepository)
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
      $parsedPackage = &$ParsePkgInfoFn -pkg $pkg

      if((CompareSemVer $parsedPackage.PackageSemVer $parsedPackage.PublishedSemVer) -ne 1)
      {
        Write-Host "Package $($parsedPackage.PackageId) is marked with version $($parsedPackage.PackageVersion), but the published PyPI pkg is marked with version $($parsedPackage.PublishedSemVer.VersionString)."
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

  return ([array]$pkgList | Sort-Object -Property Tag -uniq)
}

# VERIFY PACKAGES
$pkgList = VerifyPackages -pkgs (Get-ChildItem $artifactLocation\* -Recurse -File *) -pkgRepository $pkgRepository

Write-Host "Tags discovered from the artifacts in the artifact directory: "

foreach($packageInfo in $pkgList){
  Write-Host $packageInfo.Tag
}

# CREATE TAGS and RELEASES
CreateTags -pkgList $pkgList -apiUrl $apiUrl -releaseSha $releaseSha
CreateReleases -pkgList $pkgList -releaseApiUrl $apiUrl/releases -targetBranch $targetBranch
