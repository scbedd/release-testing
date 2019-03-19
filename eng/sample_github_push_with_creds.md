```
environment:
  access_token:
    secure: zYCOwcOlgTzvbD0CjJRDNQ==

on_success:
  - git config --global credential.helper store
  - ps: Add-Content "$HOME\.git-credentials" "https://$($env:access_token):x-oauth-basic@github.com`n"
  - git config --global user.email "Your email"
  - git config --global user.name "Your Name"
  - git commit ...
  - git push ...
```