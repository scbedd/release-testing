# assumptions
# * The repo which needs tags added should already be cloned.
# * Git has been configured with credentials already. git_configure_creds

param (
  # used by VerifyPackages
  $artifactLocation, # the root of the artifact folder. DevOps $(System.ArtifactsDirectory)
  $pkgRepository, # used to indicate destination against which we will check the existing version.

  # used by CreateTags
  $clonedRepoLocation, # the location of where the git repo has been cloned such that we can push tags up from it.
  $releaseSha, # the SHA for the artifacts. DevOps: $(Release.Artifacts.<artifactAlias>.SourceVersion)

  # used by Git Release
  # Expects $env:GH_TOKEN to be populated
  $releaseApiUrl, # API URL for github release creation. Example: 
  $targetBranch = "master" # default to master, but should be able to set where the tags end up
)

function CreateTags($packageList, $clonedRepoLocation, $releaseSha)
{
  $currentLocation = gl
  cd $clonedRepoLocation

  foreach($p in $packageList){
    $v = ($p -Split "_")[1]
    $n = ($p -Split "_")[0]

    # todo, figure out how to capture bad output from git. This should exit(1) on failure to create tags
    git tag -a $p -m "$v release of $n" $releaseSha
    git push origin $p
  }

  # return to original location
  cd $currentLocation
}

function CreateReleases($releaseTags, $releaseApiUrl, $targetBranch)
{
  foreach($releaseTag in $releaseTags)
  {
    $url = $releaseApiUrl
    $body = @{
      tag_name = $releaseTag
      target_commitish = $targetBranch
      name = $releaseTag
      draft = "false"
      prerelease = "false"
    }
    $headers = @{
      "Content-Type" = "application/json"
      "Authorization" = "token $($env:GH_TOKEN)" 
    }

    Invoke-RestMethod -Method 'Post' -Uri $url -Body $body -Headers $headers
  }
}

function ToSemVer($version)
{
  $version -match "^(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?((?<pre>[A-Za-z][0-9A-Za-z]+))?$" | Out-Null
  $major = [int]$matches['major']
  $minor = [int]$matches['minor']
  $patch = [int]$matches['patch']
  
  if($matches['pre'] -eq $null)
  {
    $pre = @()
  }
  else
  {
    $pre = $matches['pre'].Split(".")
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

  $ap = $a.Pre
  $bp = $b.Pre

  # if they have 0 length, they are equivalent
  if($ap.Length -eq 0 -and $bp.Length -eq 0) 
  {
    return 0
  }
  
  # a is blank and b is not? b is greater
  if($ap.Length  -eq 0)
  {
    return 1
  }
  
  if($bp.Length -eq 0){
    return -1
  }
  
  $minLength = [Math]::Min($ap.Length, $bp.Length)
  
  for($i = 0; $i -lt $minLength; $i++)
  {
    $ac = $ap[$i]
    $bc = $bp[$i]

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
  }

  Write-Host "We are here, which means that we haven't returned yet"
  return $ap.Length.CompareTo($bp.Length)
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

function VerifyPackages($pkgs, $pkgRepository)
{
  $pkgList = [array]@()
  $CheckFunction = ''
  $ParseFunction = ''

  switch($pkgRepository)
  {
    "Maven" {
      $CheckFunction = "InvokeMaven"
      $ParseFunction = "ParseMavenPackage"
      break
    }
    "Nuget" {
      $CheckFunction = "InvokeNuget"
      $ParseFunction = "ParseNugetPackage"
      break
    }
    "NPM" {
      $CheckFunction = "InvokeNPM"
      $ParseFunction = "ParseNPMPackage"
      break
    }
    "PyPI" {
      $CheckFunction = "InvokePyPI"
      $ParseFunction = "ParsePyPIPackage"
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
      $parsedPackage = &$ParseFunction -pkg $pkg

      $publishedVersion = ToSemVer (&$CheckFunction -pkgId $parsedPackage.PackageId)
      $pkgVersion = ToSemVer $parsedPackage.PackageVersion

      if((CompareSemVer $pkgVersion $publishedVersion) -ne 1)
      {
        Write-Host "Package $($parsedPackage.PackageId) is marked with version $($pkgVersion.versionString), but the published PyPI pkg is marked with version $($publishedVersion.versionString)."
        Write-Host "Maybe a pkg version wasn't updated properly?"
        exit(1)
      }

      $pkgList += ($parsedPackage.PackageId + "_" +($pkgVersion.versionString))
    }
    catch 
    {
      Write-Host $_.Exception.Message
      exit(1)
    }
  }

  return $pkgList
}

# VERIFY PACKAGES
$pkgList = VerifyPackages -pkgs (Get-ChildItem $artifactLocation\* -Recurse -File *) -pkgRepository $pkgRepository
$pkgList = ([array]$pkgList | select -uniq)

# CREATE TAGS
CreateTags -packageList $pkgList -clonedRepoLocation $clonedRepoLocation -releaseSha $releaseSha

# CREATE RELEASES
CreateReleases -releaseTags $pkgList -releaseApiUrl $releaseApiUrl -targetBranch $targetBranch