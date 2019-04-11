## GitHub Releases

We use GitHub releases as a convenient place to put release notes. The change log and any additional notes will be available here. ES automation will automatically publish release notes to a GitHub release if the changelog guidance below is followed. No artifacts are published to the GitHub release. Instead, use a supported package registry.

## ChangeLog Guidance

We recommend that every package maintain a changelog just a matter of course. However, there is an additional benefit. Ensuring that a `changelog.md` file is both available and formatted appropriately will result in automatically formatted release notes on each GitHub release. 

How?

* **.NET:** extend nuspec to include `changelog.md` in the `.nupkg.` 
* **Java:** add `changelog.md` to the existing artifact list.
* **JS:** ensure `changelog.md` is included in the package tarball.
* **Python:** ensure `changelog.md` is present in the `sdist` artifact.

A given `changelog.md` file must follow the below form:

```
# <release date in YYYY-MM-DD> - <versionSpecifier>

<content. as long as it doesn't introduce another header that looks like the one above>

...additional changelog entries

```

During release, if there exists a changelog entry with a version specifier _matching_ that of the currently releasing package, that changelog entry will be added as the body of the GitHub release.

The [JS ServiceBus SDK](https://github.com/Azure/azure-sdk-for-js/blob/master/sdk/servicebus/service-bus/changelog.md) maintains a great changelog example. Given that changelog, this is what a [release](https://github.com/Azure/azure-sdk-for-js/releases/tag/%40azure%2Fservice-bus_1.0.0-preview.2) looks like.

---
topic: sample
description: Provides base sample driver that IHVs and partners can use to extend to build their custom Windows GPS/GNSS drivers.
languages:
- cpp
products:
- windows
---