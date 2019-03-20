# retrieve the information for each of the passed packages

# example arguments: -url "$(target_repo)" -rootDir $(System.ArtifactsDirectory)/../ -targetFolder repo_folder
param (
  $url,
  $rootDir,
  $targetFolder
)

cd $rootDir
git clone $url $targetFolder

