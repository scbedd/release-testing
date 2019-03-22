function ToSemVer($version){
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

function CompareSemVer($a, $b){
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

$v1 = ToSemVer "1.1.1rc2"
$v2 = ToSemVer "1.1.1rc1"
$v3 = ToSemVer "1.1.1"
$v4 = ToSemVer "1.1.0"
$v5 = ToSemVer "0.0.1"
$v6 = ToSemVer "0.0.0"

# Write-Host "$($v1.VersionString) vs $($v2.VersionString)" 
# Write-Host (CompareSemVer -a $v1 -b $v2)

# Write-Host "$($v2.VersionString) vs $($v3.VersionString)" 
# Write-Host (CompareSemVer -a $v2 -b $v3)

# Write-Host "$($v1.VersionString) vs $($v3.VersionString)" 
# Write-Host (CompareSemVer -a $v1 -b $v3)

# Write-Host "$($v4.VersionString) vs $($v3.VersionString)" 
# Write-Host (CompareSemVer -a $v4 -b $v3)

Write-Host "$($v3.VersionString) vs $($v4.VersionString)" 
Write-Host (CompareSemVer -a $v3 -b $v4)

Write-Host "$($v5.VersionString) vs $($v6.VersionString)" 
Write-Host (CompareSemVer -a $v5 -b $v6)