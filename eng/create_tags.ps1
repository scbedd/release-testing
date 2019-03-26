function CreateTags($pkgList, $apiUrl, $releaseSha)
{
  # common headers. don't need to define multiple times
  $headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "token $($env:GH_TOKEN)" 
  }

  foreach($pkgInfo in $pkgList){
    Write-Host "Writing $($pkgInfo.Tag)"

    try {
      $tagObjectBody = ConvertTo-Json @{
        tag = $pkgInfo.Tag
        message = "$($pkgInfo.PackageVersion) release of $($pkgInfo.PackageId)"
        object = $releaseSha
        type = "commit"
        tagger = @{
          name = "Azure SDK Engineering System"
          email = "azuresdkeng@microsoft.com"
          date = Get-Date -Format "o"
        }
      }

      $outputSHA = (Invoke-RestMethod -Method 'Post' -Uri $apiUrl/git/tags -Body $tagObjectBody -Headers $headers).sha

      $refObjectBody = ConvertTo-Json @{
        "ref" = "refs/tags/$($pkgInfo.Tag)"
        "sha" = $outputSHA
      }

      $result = (Invoke-RestMethod -Method 'Post' -Uri $apiUrl/git/refs -Body $refObjectBody -Headers $headers)
    }
    catch 
    {
      $statusCode = $_.Exception.Response.StatusCode.value__
      $statusDescription = $_.Exception.Response.StatusDescription

      Write-Host "Tag creation failed with statuscode $statusCode. Reason: "
      Write-Host $statusDescription
      exit(1)
    }
  }
}