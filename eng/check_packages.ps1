# retrieve the information for each of the passed packages
param (
  $artifactLocation
)

function Invoke-PyPI($name)
{

}

function Verify-Package-Wheels($wheels)
{
  foreach ($wheel in $wheels)
  {
    try 
    {
      $packageList += $wheel
    }
    catch 
    {
      Write-Host $_.Exception.Message
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








