# retrieve the information for each of the passed packages
git config --global credential.helper store
Add-Content "$HOME\.git-credentials" "https://$($env:GH_TOKEN):x-oauth-basic@github.com`n"
git config --global user.email "azuresdkeng@microsoft.com"
git config --global user.name "Azure SDK Team"

