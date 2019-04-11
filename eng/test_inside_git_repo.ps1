  try {
    git rev-parse --is-inside-work-tree
  }
  catch 
  {
    Write-Host "This script should be executed inside a working git repository."
  }