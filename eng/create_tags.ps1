# retrieve the information for each of the passed packages

param (
    $package_list,
    $target_repo
)

# just getting this working
# will place an output variable for the tagname eventually

cd $target_repo

foreach($p in $package_list -Split ","){
    git tag -a $p -m "Release Tag for Package: $p"
    git push origin :refs/tags/$p
}

