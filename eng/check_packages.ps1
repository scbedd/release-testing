# retrieve the information for each of the passed packages
param (
  $artifactLocation
)

function verifyPackageWheel($wheel)
{
    Write-Host $wheel
}

function verifyPackageSDist($tar)
{
    Write-Host $tar
}

# wheels
foreach ($wheel in (Get-ChildItem $artifactLocation\* -Recurse -Include *.whl))
{
   try 
   {
        verifyPackageWheel($wheel)
   }
   catch 
   {
        Write-Host $_.Exception.Message
   }
}

# sdist
foreach ($tar in (Get-ChildItem $artifactLocation\* -Recurse -Include *.tar.gz))
{
   try 
   {
        verifyPackageSDist($tar)
   }
   catch 
   {
        Write-Host $_.Exception.Message
   }
}