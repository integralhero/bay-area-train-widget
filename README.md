# TrainWidget

A Bay Area transit widget for iOS. Shows real-time departures from the stops nearest your current location, on the home screen and the lock screen.

Supports MUNI Metro, MUNI Bus, BART, and AC Transit. Departures come from [511.org](https://511.org)'s public transit API (free, free key required).

## Features

- **Auto-detects nearest stops** using Core Location — walk to a different stop and the widget follows you.
- **Multiple widget sizes**: small, medium, large, plus accessory rectangular / circular / inline for the lock screen.
- **Per-agency line filtering**: star the lines you actually ride and they're prioritized on the lock screen.
- **Smart fetching**: shared rate-limit cooldown, response cache between widget families, and a 100m co-location carve-out so multi-platform corners (e.g. Church & Market) query both the surface and underground stops.
- **Bay Area only** — explicitly. Outside the region, the widget says so instead of showing stale data.

## Requirements

- macOS with Xcode 16 or later
- iOS 17.0+ on the target device
- An Apple Developer account (free tier works for personal devices; paid tier needed if you want widgets on a real device for more than 7 days)
- A free 511.org API key — [get one here](https://511.org/open-data/token)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for regenerating the Xcode project from `project.yml`:
  ```bash
  brew install xcodegen
  ```

## Setup

### 1. Clone

```bash
git clone https://github.com/YOUR_USERNAME/train-widget.git
cd train-widget
```

### 2. Set your Apple Developer Team ID

Copy the example xcconfig and fill in your team ID:

```bash
cp Configs/Local.xcconfig.example Configs/Local.xcconfig
```

Then edit `Configs/Local.xcconfig` and replace `YOUR_TEAM_ID_HERE` with your Apple Developer Team ID (find it at https://developer.apple.com/account#MembershipDetailsCard).

`Configs/Local.xcconfig` is gitignored so your team ID never lands in version control.

### 3. Replace bundle identifiers

Forks need a unique bundle ID prefix and app group. Find-and-replace these strings across the repo:

| String | Where | Replace with |
|--------|-------|--------------|
| `com.trainwidget` | `project.yml` (lines 3, 29, 48) | your reverse-DNS prefix, e.g. `com.yourname` |
| `group.com.trainwidget.app` | `TrainWidget/TrainWidget.entitlements`, `TrainWidgetExtension/TrainWidgetExtension.entitlements`, `Shared/UserDefaultsStore.swift` (line 5) | a unique app group, e.g. `group.com.yourname.trainwidget` |

The app group identifier must match in all three places — the main app and the widget extension share data through it.

### 4. Generate the Xcode project

The `.xcodeproj` is not checked in — it's generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate
```

Re-run this any time you change `project.yml` or add files to a target.

### 5. Open and run

```bash
open TrainWidget.xcodeproj
```

In Xcode:
1. Select the `TrainWidget` scheme and your device (or simulator).
2. Cmd+R to build and run.
3. On first launch, grant location permission.
4. Enter your 511.org API key in the **Setup** screen.
5. Add a TrainWidget to your home screen / lock screen.

### 6. Configure your lines

Open the app and toggle the agencies you ride. Tap individual line chips to star them — starred lines are prioritized on the lock screen widget. Unstarred = show everything.

## Project structure

```
Shared/                          Code shared between app + widget extension
  Models.swift                   TransitAgency, TransitStop, Departure
  TransitAPI.swift               511.org StopMonitoring client
  StopFinder.swift               Haversine nearest-stop search
  StopData.swift                 Bundled + dynamically-fetched stop list
  UserDefaultsStore.swift        App group UserDefaults wrapper
  stops.json                     Pre-bundled stop coordinates

TrainWidget/                     The main app (configuration UI)
TrainWidgetExtension/            The widget extension
  DepartureTimelineProvider.swift  WidgetKit timeline + fetch logic
  DepartureWidget.swift            Lock screen widget views
  HomeWidgetViews.swift            Home screen (small/medium/large) views
```

## Why a 100m co-location carve-out?

The widget normally stops querying after the first nearby stop returns ≥4 departures, to conserve API quota. But places like Church & Market have an underground KLM platform and a separate surface J stop within 30m of each other — the underground stop's chatter would otherwise hide the J entirely. The widget always queries every stop within 100m of your location, regardless of how loud the first one is.

## Contributing

Issues and PRs welcome. The code aims to stay small and focused — please match that style.

## License

[MIT](LICENSE).
