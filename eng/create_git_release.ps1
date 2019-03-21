param (
  $ghToken,
  $releaseTags,
  $artifactSHA,
  $releaseURL, # Sample Github URL for azure-sdk-for-python: https://api.github.com/repos/scbedd/release-testing/releases
  $targetBranch = "master"
)

function CreateRelease($releaseTag, $ghToken, $releaseURL, $targetBranch)
{
  $url = $releaseURL
  $body = @{
    tag_name = $releaseTag
    target_commitish = "master"
    name = $releaseTag
    draft = "false"
    prerelease = "false"
  }
  $headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "token $ghToken" 
  }

  Invoke-RestMethod -Method 'Post' -Uri $url -Body $body -Headers $headers

  if ($LastExitCode -ne 0)
  {
    Write-Host "Git Release Failed with exit code: $LastExitCode."
    exit 1
  }
}

foreach($tag in ($releaseTags -Split ","))
{
    CreateRelease -releaseTag $releaseTag -ghToken $ghToken
}
