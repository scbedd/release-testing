Function ExtractReleaseNotes($changeLogLocation)
{
  $contents = Get-Content -Raw $changeLogLocation  
  $titles = Select-String $TEST_REGEX -input $contents -AllMatches | % { $_.matches }
  $releaseNotes = @()

  for ($i=0; $i -lt $titles.Length; $i++)
  {
    $match = $titles[$i].Groups['releaseTitle']
    $noteVersion = $titles[$i].Groups['version']

    $noteStartIndex = $contents.IndexOf($match)
    $noteEndIndex = if ($i -eq ($titles.Length - 1)) { $contents.Length } else { $contents.IndexOf($titles[$i + 1].Groups['releaseTitle'])}

    Write-Host "Title: $match"
    Write-Host "SI: $noteStartIndex"
    Write-Host "EI: $noteEndIndex"

    $releaseNote = New-Object PSObject -Property @{
      ReleaseTitle = $match
      ReleaseContent = $contents.SubString($noteStartIndex, ($noteEndIndex - $noteStartIndex))
      ReleaseVersionNumber = $noteVersion
    }

    $releaseNotes += $releaseNote
  }

  return $releaseNotes
}

$TEST_REGEX = "(?<releaseTitle>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+))))"
$VERSION_REGEX = "(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+))"
$SAMPLE_CHANGELOG_LOCATION = "C:/repo/sdk-for-js/sdk/servicebus/service-bus/changelog.md"

$a = ExtractReleaseNotes -changeLogLocation $SAMPLE_CHANGELOG_LOCATION

foreach($bleh in $a)
{
  Write-Host $bleh
}

# https://stackoverflow.com/questions/12572164/multiline-regex-to-match-config-block

# https://regex101.com/r/X2jaMC/3

# eating everything
# (?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>(?!\#\ )[\s\S]*))

# failing
# (?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>[\s\S]*?^(# )))

# failing 2
# (?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>[\s\S]*?(?=# )))


# (?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>(.*?)\#\ ))
# (?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>(.*?)\#\ ))

