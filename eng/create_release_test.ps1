$url = 'https://api.github.com/repos/scbedd/release-testing/releases'
$body = ConvertTo-Json @{
  tag_name = 'test-creation'
  target_commitish = $releaseSha
  name = 'test-creation'
  draft = $False
  prerelease = $False
  body = ''
}

$headers = @{
  "Content-Type" = "application/json"
  "Authorization" = "token $($env:roflmao)" 
}

try {
  Invoke-RestMethod -Method 'Post' -Uri $url -Body $body -Headers $headers
}
catch {
  $statusCode = $_.Exception.Response.StatusCode
  $statusDescription = $_.Exception.Response.StatusDescription

  Write-Host $_.Exception.Response.Content
  Write-Host $_.Exception.Response.Message
e
  Write-Host ($_.Exception.Response.Content| Format-Table | Out-String)

  Write-Host "Release request to $releaseApiUrl failed with statuscode $statusCode"
  Write-Host $statusDescription
  exit(1)
}