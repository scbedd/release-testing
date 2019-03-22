# retrieve the information for each of the passed packages

param (
    
)

# just getting this working
# will place an output variable for the tagname eventually

function CreateTags($packageList, $clonedRepoLocation, $releaseSha)
{
  $currentLocation = gl
  cd $clonedRepoLocation

  foreach($p in $packageList -Split ","){
    $v = ($p -Split "_")[1]
    $n = ($p -Split "_")[0]

    git tag -a $p -m "$v release of $n" $releaseSha
    git push origin $p
  }

  # return to original location
  cd $currentLocation
}