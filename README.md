# TrainWidget

An iOS widget that shows when the next train or bus is leaving from the stops near you. Works across the Bay Area: MUNI Metro, MUNI Bus, BART, and AC Transit.

Departures come from the [511.org](https://511.org) open transit API. You'll need a free key to run it.

## Features

- Finds the nearest stop automatically using Core Location. Walk a few blocks and the widget follows along.
- Home screen widgets in small, medium, and large sizes.
- Lock screen widgets in rectangular, circular, and inline accessory styles.
- Lets you star the lines you actually ride. On the lock screen, where space is tight, starred lines get priority.
- Plays nicely with the 511 quota: a shared rate-limit cooldown, a response cache between widget families, and a small carve-out for multi-platform corners so an underground stop can't drown out the surface stop sitting next to it.
- Knows it only works in the Bay Area. If you wander out of range it says so, instead of pretending.

## Requirements

- macOS with Xcode 16 or later
- iOS 17.0+ on the target device
- An Apple Developer account. The free tier is fine for personal devices; you'll want the paid tier if you need widgets to keep running on a real device for more than seven days.
- A free 511.org API key. [Get one here](https://511.org/open-data/token).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). It generates the Xcode project from `project.yml`.

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

Then edit `Configs/Local.xcconfig` and replace `YOUR_TEAM_ID_HERE` with your Apple Developer Team ID. You can find yours at https://developer.apple.com/account#MembershipDetailsCard.

`Configs/Local.xcconfig` is gitignored, so your team ID never lands in version control.

### 3. Replace bundle identifiers

If you're forking, you'll need your own bundle prefix and app group. Find-and-replace these strings across the repo:

| String | Where | Replace with |
|--------|-------|--------------|
| `com.trainwidget` | `project.yml` (lines 3, 29, 48) | your reverse-DNS prefix, e.g. `com.yourname` |
| `group.com.trainwidget.app` | `TrainWidget/TrainWidget.entitlements`, `TrainWidgetExtension/TrainWidgetExtension.entitlements`, `Shared/UserDefaultsStore.swift` (line 5) | a unique app group, e.g. `group.com.yourname.trainwidget` |

The app group has to match in all three places. That's how the main app and the widget extension talk to each other.

### 4. Generate the Xcode project

The `.xcodeproj` isn't checked in. XcodeGen builds it from `project.yml`:

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
5. Add a TrainWidget to your home screen or lock screen.

### 6. Pick your lines

Open the app and toggle on the agencies you ride. Tap line chips to star the ones you actually take. Starred lines get priority on the lock screen widget. With nothing starred, you'll see everything.

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

## Contributing

Issues and PRs welcome. The code is small on purpose; if you're sending a patch, please keep it that way.

## License

[MIT](LICENSE).
