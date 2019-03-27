$testArray = @(
  ,@("1.0.0", "1.0.1", -1)
  ,@("1.0.1", "1.0.1rc1", -1)
  ,@("1.0.1rc1", "1.0.1", 1)
  ,@("2.0.0-preview.1", "2.0.0", 1)
  ,@("2.0.0", "2.0.0", 0)
  ,@("2.0.0-preview.2", "2.0.0", 1)
  ,@("2.0.0", "2.0.0-preview.2", -1)
  ,@("1.0.1rc1", "1.0.1rc2", -1)
  ,@("2.0.0-preview.1", "2.0.0-preview.2", -1)
  ,@("2.0.0-preview.2", "2.0.0-preview.1", 1)
)


$VERSION_REGEX = "(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?((?<pre>[^0-9][^\s]+))?"
$SEMVER_REGEX = "^$VERSION_REGEX$"
$TAR_SDIST_PACKAGE_REGEX = "^(?<package>.*)\-(?<versionstring>$VERSION_REGEX$)"

function ToSemVer($version)
{
  $version -match $SEMVER_REGEX | Out-Null
  $major = [int]$matches['major']
  $minor = [int]$matches['minor']
  $patch = [int]$matches['patch']

  if($matches['pre'] -eq $null)
  {
    $pre = ""
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
    return -1
  }
  
  if($b.Pre.Length -eq 0){
    return 1
  }
  
  $aParts = $a.Pre.Split(".")
  $bParts = $b.Pre.Split(".")

  $minLength = [Math]::Min($aParts.Length, $bParts.Length)

  for($i = 0; $i -lt $minLength; $i++)
  {
    $ac = $aParts[$i]
    $bc = $bParts[$i]

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

    if($aIsNum -and !$bIsNum)
    {
      return -1
    }

    if($bIsNum -and !$aIsNum)
    {
      return 1
    }

    $result = [string]::CompareOrdinal($ac, $bc)

    if($result -ne 0)
    {
      return $result
    }
  }

  return $a.Pre.Length.CompareTo($b.Pre.Length)
}

foreach($testSet in $testArray)
{
  $a = ToSemVer $testSet[0]
  $b = ToSemVer $testSet[1]

  $result = CompareSemVer -a $a -b $b

  if($result -ne $testSet[2])
  {
    Write-Host "$($testSet[0]) compared against $($testSet[1]) with $result instead of expected $($testSet[2])"
  }
}