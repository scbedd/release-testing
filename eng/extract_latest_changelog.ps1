# given a changelog.md file, extract the relevant info we need to decorate a release
function ExtractReleaseNotes($changeLogLocation)
{
  $releaseNotes = @{}
  $contentArrays = @{}
  if ($changeLogLocation.Length -eq 0)
  {
    return $releaseNotes
  }

  try {
    $contents = Get-Content $changeLogLocation

    # walk the document, finding where the version specifiers are and creating lists
    $version = ''
    foreach($line in $contents){
      if ($line -match $RELEASE_TITLE_REGEX)
      {
        $version = $matches['version']
        $contentArrays[$version] = @()
      }
      
      $contentArrays[$version] += $line
    }

    # resolve each of discovered version specifier string arrays into real content
    foreach($key in $contentArrays.Keys)
    {
      $releaseNotes[$key] = New-Object PSObject -Property @{
        ReleaseVersion = $key
        ReleaseContent = $contentArrays[$key] -join [Environment]::NewLine
      }
    }
  }
  catch
  {
    Write-Host "Error parsing $changeLogLocation."
    Write-Host $_.Exception.Message
  }

  return $releaseNotes
}

function CheckLines($changeLogLocation)
{
  Write-Host $TITLE_REGEX
  $contents = Get-Content $changeLogLocation

  foreach($line in $contents)
  {
    if($line -match $TITLE_REGEX)
    {
      Write-Host $line
      Write-Host $matches['version']
    }
  }
}

$RELEASE_NOTE_REGEX = "(?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s-\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>((?!\s# )[\s\S])*))"
$VERSION_REGEX = "(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+))"
$RELEASE_TITLE_REGEX = "(?<releaseNoteTitle>\#(?<preVersion>[\s]*?)(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+))))"
$SAMPLE_CHANGELOG_LOCATION = "C:/repo/sdk-tools/packages/python-packages/doc-warden/changelog.md" #"C:/repo/sdk-for-js/sdk/servicebus/service-bus/changelog.md"

$UNCAPTURED_VERSION_REGEX = "(\d+\.\d+\.\d+([^0-9][^\s]*))"
$CAPTURED_VERSION_REGEX = "(?<version>\d+\.\d+\.\d+([^0-9][^\s]*))"
$NEGATIVE_LOOKAHEAD_REGEX = "((?!$UNCAPTURED_VERSION_REGEX)[\s\S])*"
$TITLE_REGEX = "(?<releaseNoteTitle>^\#\s$NEGATIVE_LOOKAHEAD_REGEX$CAPTURED_VERSION_REGEX)"

# working https://regex101.com/r/qpvdwv/4
$RELEASE_TITLE_REGEX = "(?<releaseNoteTitle>^\#\s.*(?<version>\d+\.\d+\.\d+([^0-9][^\s]+)?))"

return ExtractReleaseNotes -changeLogLocation $SAMPLE_CHANGELOG_LOCATION
#CheckLines -changeLogLocation $SAMPLE_CHANGELOG_LOCATION

# https://stackoverflow.com/questions/12572164/multiline-regex-to-match-config-block

# https://regex101.com/r/X2jaMC/6 <-- working title regex

# eating everything
# (?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>(?!\#\ )[\s\S]*))

# failing
# (?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>[\s\S]*?^(# )))

# failing 2
# (?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>[\s\S]*?(?=# )))


# (?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>(.*?)\#\ ))
# (?<releaseNote>\#\s(?<releaseDate>[\-0-9]+)\s(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+)))(?<releaseText>(.*?)\#\ ))

#(?<releaseNoteTitle>\#([\s]*?)(?<version>(\d+)(\.(\d+))?(\.(\d+))?(([^0-9][^\s]+))))
