# retrieve the information for each of the passed packages

param (
    $package_list,
    $target_repo
)

# just getting this working
# will place an output variable for the tagname eventually

cd $target_repo

git status

foreach($p in $package_list -Split ","){
    Write-Host "$p"
    Write-Host "git tag -a $p -m 'Release Tag for Package: $p'"
    Write-Host "git push origin :refs/tags/$p"
    git tag -a $p -m "Release Tag for Package: $p"
    git push origin :refs/tags/$p
}

