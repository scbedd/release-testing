# retrieve the information for each of the passed packages

param (
  $url,
  $rootDir,
  $targetFolder
)

cd rootDir
git clone $url $targetFolder
