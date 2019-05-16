# A little script to get all active PRS from a github repo. Filter by a label if you wish.
# 
#
# EXAMPLE USAGE
# 
# ./interrogate_active_prs.ps1 -labelFilter Dev -gh_token <YOUR GITHUB PAT> -repoName release-testing -repoOwner scbedd
#
# or copy this script locally, set the default repo and owner, set and environment variable of name GH_TOKEN with your PAT, and 
# run it simply with a labelfilter if you want.
param (
  $ghToken = "",
  $labelFilter = "ServicePR",
  $repoOwner = "Azure", # the owning organization of the repository. EG "Azure"
  $repoName = "azure-sdk-for-python"# the name of the repository. EG "azure-sdk-for-java"
)

function FireAPIRequest($url, $method, $body = $null, $headers = $null)
{
  $attempts = 1
  
  while($attempts -le 3)
  {
    try 
    {
      return Invoke-RestMethod -Method $method -Uri $url -Body $body -Headers $headers -FollowRelLink

    }
    catch 
    {
      $response = $_.Exception.Response

      $statusCode = $response.StatusCode.value__
      $statusDescription = $response.StatusDescription
      
      Write-Host "API request attempt number $attempts to $url failed with statuscode $statusCode"
      Write-Host $statusDescription

      Write-Host "Rate Limit Details:"
      Write-Host "Total: $($response.Headers.GetValues("X-RateLimit-Limit"))"
      Write-Host "Remaining: $($response.Headers.GetValues("X-RateLimit-Remaining"))"
      Write-Host "Reset Epoch: $($response.Headers.GetValues("X-RateLimit-Reset"))"

      if ($attempts -gt 3)
      {
        Write-Host "Abandoning Request $url after 3 attempts."
        exit(1)
      }

      Start-Sleep -s 10
    }

    $attempts += 1
  }
}

# credit to https://stackoverflow.com/a/33545660 for this beautiful piece of software
function Flatten-Array{
    $input | ForEach-Object{
        if ($_ -is [array]){$_ | Flatten-Array}else{$_}
    } | Where-Object{![string]::IsNullorEmpty($_)}
    # | Where-Object{$_} would also work.
}

# fall back to environment variable
if($ghToken -eq "")
{
  $ghToken = $env:GH_TOKEN
}

$COMMON_AUTH_HEADER = @{
  "Content-Type" = "application/json"
  "Authorization" = "token $ghToken" 
}

$apiUrl = "https://api.github.com/repos/$repoOwner/$repoName"
$prListUrl = "$apiUrl/pulls"


$pullRequests = FireAPIRequest -url $prListUrl -method "Get" | Flatten-Array

$filteredContent = @()

foreach($pullRequest in $pullRequests)
{
  if(($pullRequest.labels | ? { $_.name -eq $labelFilter }) -eq $null)
  {
    $filteredContent += $pullRequest
  }
}

$content | ConvertTo-Json | Out-File "./all.json"
$filteredContent | ConvertTo-Json | Out-File "./filtered.json"

return $content
