# retrieve the information for each of the passed packages

param (
  $artifactList
)

foreach ( $p in(Get-ChildItem $pathToArtifacts -Recurse -Filter "*.tgz" -File) ){
    try{
        Write-Host "npm publish $($p.FullName) --access=$accessLevel --registry=$registry --always-auth=true $tag"
        npm publish $p.FullName --access=$accessLevel --registry=$registry --always-auth=true $tag
    }
    catch{
        $ErrorMessage = $_.Exception.Message
        Write-Host $ErrorMessage
    }
}



