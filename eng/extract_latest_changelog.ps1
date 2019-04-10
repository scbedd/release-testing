# given a changelog.md file, extract the relevant info we need to decorate a release
function ExtractReleaseNotes($changeLogLocation)
{
  $releaseNotes = @{}
  if ($changeLogLocation.Length -eq 0)
  {
    return $releaseNotes
  }

  $contents = Get-Content -Raw $changeLogLocation
  $noteMatches = Select-String $RELEASE_NOTE_REGEX -input $contents -AllMatches | % { $_.matches }

  foreach($releaseNoteMatch in $noteMatches)
  {
    $version = $releaseNoteMatch.Groups['version'].Value
    $text = $releaseNoteMatch.Groups['releaseText'].Value

    $releaseNotes[$version] = New-Object PSObject -Property @{
      ReleaseContent = $text
    }
  }

  return $releaseNotes
}

$RELEASE_NOTE_REGEX = "(?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>((?!\s# )[\s\S])*))"
$VERSION_REGEX = "(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+))"
$SAMPLE_CHANGELOG_LOCATION = "C:/repo/sdk-for-js/sdk/servicebus/service-bus/changelog.md"

$a = ExtractReleaseNotes -changeLogLocation $SAMPLE_CHANGELOG_LOCATION




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

