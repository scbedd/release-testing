# retrieve the information for each of the passed pkgs
param (
  $artifactLocation
)

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

  $c = $a
  $a = $b
  $b = $c

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

# invokes PYPI, returns the existing version of a pkg.
# if it can't find that pkg, returns version 0.0.0.0
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

function VerifyPackages($pkgs)
{
  $pkgList = [array]@()

  foreach ($pkg in $pkgs)
  {
    try 
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

          $pkgId = $nameParts[1..($nameParts.Length - 1)] -join "-"
          $pkgVersion = $nameParts[($nameParts.Length)]
        }
        else {
          Write-Host "Not a recognized pkg type: $extension"
          exit(1)
        }  
      }

      $publishedVersion = ToSemVer (InvokePyPI -pkgId $pkgId)
      $pkgVersion = ToSemVer $pkgVersion

      if((CompareSemVer $pkgVersion $publishedVersion) -ne -1)
      {
        Write-Host "Package $pkgId is marked with version $($pkgVersion.versionString), but the published PyPI pkg is marked with version $($publishedVersion.versionString)."
        Write-Host "Maybe a pkg version wasn't updated properly?"
        exit(1)
      }

      $pkgList += ($pkgId + "_" +($pkgVersion.versionString))
    }
    catch 
    {
      Write-Host $_.Exception.Message
      exit(1)
    }
  }

  return $pkgList
}

$pkgList = VerifyPackages -pkgs (Get-ChildItem $artifactLocation\* -Recurse -Include *.whl,*.tar.gz)
$pkgList = ([array]$pkgList | select -uniq) -join ","

# set the output variable for the task
Write-Host "##vso[task.setvariable variable=PackageList]$pkgList"
