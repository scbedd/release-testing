git pull
git tag -d azure-template_0.1.0
git push origin :refs/tags/azure-template_0.1.0
git tag -d azure-template-copy_0.1.0
git push origin :refs/tags/azure-template-copy_0.1.0


git tag -d manual-lightweight-tag
git push origin :refs/tags/manual-lightweight-tag
git tag manual-lightweight-tag
git push origin manual-lightweight-tag