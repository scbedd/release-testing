# retrieve the information for each of the passed packages
param (
  $artifactLocation
)

function Invoke-PyPI($packageId, $existingPackageVersion)
{
  try {
    return (Invoke-RestMethod -Method 'Get' -Uri "https://pypi.org/pypi/$packageId/json").info.version
  }
  catch 
  {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription
    
    # if this is 404ing, then this package has never been published before
    if($statusCode -eq 404)
    {
      return "0.0.0.0"
    }

    Write-Host "PyPI Invocation failed:"
    Write-Host "StatusCode:" $statusCode
    Write-Host "StatusDescription:" $statusDescription
    exit(1)
  }
}

function Verify-Package-Wheels($wheels)
{
  $packageList = [array]@()

  foreach ($wheel in $wheels)
  {
    try 
    {
      $nameParts = $wheel.Basename -Split "_"

      $packageId = $nameParts[0]
      $packageVersion = $nameParts[1]
      $publishedVersion = (Invoke-PyPI -packageId $packageId -existingPackageVersion $packageVersion)

      if($publishedVersion -gt $packageVersion)
      {
        Write-Host "Package $packageId is marked with version $packageVersion, but the published PyPI package is marked with version $publishedVersion$."
        Write-Host "Maybe a package version wasn't updated properly?"
        exit(1)
      }

      $packageList += $packageId + "_" + $packageVersion 
    }
    catch 
    {
      Write-Host $_.Exception.Message
      exit(1)
    }
  }

  return $packageList
}

function Verify-Package-SDists($tars)
{
  foreach ($tar in $tars)
  {
    try 
    {
      $packageList += $tar
    }
    catch 
    {
      Write-Host $_.Exception.Message
      exit(1)
    }
  }
  
  return $packageList
}

# wheels
$wheels = Verify-Package-Wheels -wheels (Get-ChildItem $artifactLocation\* -Recurse -Include *.whl)
$tars = Verify-Package-SDists -tars (Get-ChildItem $artifactLocation\* -Recurse -Include *.tar.gz)

$packageList = ([array]$wheels + $tars | select -uniq) -join ","

# set the output variable for the task
Write-Host "##vso[task.setvariable variable=PackageList]"








