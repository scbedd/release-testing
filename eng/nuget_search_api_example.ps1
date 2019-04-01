  # first hit up the index
  $serviceIndex = Invoke-RestMethod -Method 'GET' -Uri "https://docs.microsoft.com/en-us/nuget/api/service-index"

  # in the index, we will have two that match the @type.
  # I don't really care which we choose, so I just take the first one (usually ends up the primary))
  $searchQueryService = ($serviceIndex.resources | where { $_."@type" -eq "SearchQueryService"})[0]

  # form a search term
  #T {@id}?q={QUERY}&skip={SKIP}&take={TAKE}&prerelease={PRERELEASE}&semVerLevel={SEMVERLEVEL}
  $packageEncoded = [uri]::EscapeUriString($pkgId)

  #$results = Invoke-RestMethod -Method 'GET' -Uri "$($searchQueryService."@id")?q=$packageEncoded&prerelease=true"

  https://www.nuget.org/packages/Azure.Base/1.0.0-preview.3

  # if one doesn't come back with the appropriate version, then the nuget package isn't published
