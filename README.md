<p align="center"><img src="fastlane/metadata/android/en-AU/images/featureGraphic.png" alt="Duel" width="640"></p>

# Duel

Card games, head to head: play another player online, or practise against
a bot. Early days: the first games are on the way.

## Getting it

Every update builds a new release automatically. Open
**[Releases](../../releases)** and take the latest build.

**Android:** Duel is in testing on Google Play. The `Duel-N.apk` in
Releases can also be installed by hand, but it can't update a copy
installed from Play, or the other way round.

**iPhone (experimental):** download `Duel-N.ipa` and install it with
[Sideloadly](https://sideloadly.io) and a free Apple ID. Free-account
installs expire after 7 days; re-sideload to renew.

## Building from source

Needs Flutter (stable, 3.47 or newer).

```bash
flutter create --org com.dingo --project-name duel --platforms android,ios .
flutter pub get
flutter run --release
```

The repository only holds the platform files we changed; `flutter create`
fills in the rest without overwriting them. Checks: `flutter analyze` and
`flutter test`.

| Where | What |
|---|---|
| `lib/` | The app |
| `test/` | Unit and widget tests |
| `tool/` | Icon generator, Play "What's new" script |
| `fastlane/` | Google Play store listing |
| `docs/` | [Release checklist](docs/RELEASE.md), [change log](docs/CHANGELOG.md), [privacy policy](docs/PRIVACY.md) |

Built with Flutter.
