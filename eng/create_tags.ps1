# retrieve the information for each of the passed packages

param (
    $package_list,
    $target_repo,
    $release_sha
)

# just getting this working
# will place an output variable for the tagname eventually

cd $target_repo

git status

foreach($p in $package_list -Split ","){
    $v = ($p -Split "_")[1]
    $n = ($p -Split "_")[0]

    git tag -a $p -m "$v release of $n" $release_sha
    git push origin $p
}

