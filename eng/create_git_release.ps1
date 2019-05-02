param (
  $releaseTag = "manual_release_2",
  $releaseURL = "https://api.github.com/repos/scbedd/release-testing/releases", # Sample Github URL for azure-sdk-for-python: https://api.github.com/repos/scbedd/release-testing/releases
  $targetBranch = "master"
)

function CreateRelease($releaseTag, $releaseURL, $targetBranch)
{
  $url = $releaseURL
  $body = ConvertTo-Json @{
    tag_name = $releaseTag
    target_commitish = $targetBranch
    name = $releaseTag
    draft = $False
    body = $null
    prerelease = $False
  }
  $headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "token $($env:GH_TOKEN)" 
  }

  Write-Host $body
  Write-Host $headers.Authorization

  try {
    Invoke-RestMethod -Method 'Post' -Uri $url -Body $body -Headers $headers  
  }
  catch {
    $response = $_.Exception.Response

    $statusCode = $response.StatusCode.value__
    $statusDescription = $response.StatusDescription

    return $_.Exception.Response

    Write-Host "Release request failed with statuscode $statusCode"
    Write-Host $statusDescription
    exit(1)
  }

  Write-Host $LastExitCode

  if ($LastExitCode -ne 0)
  {
    Write-Host "Git Release Failed with exit code: $LastExitCode."
    exit 1
  }
}

foreach($tag in ($releaseTags -Split ","))
{
    return CreateRelease -releaseTag $releaseTag -ghToken $ghToken -releaseURL $releaseURL
}
