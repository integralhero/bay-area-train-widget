# Bay Area Train Widget

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
- An Apple Developer account. The free tier works on your own devices, but sideloaded apps expire after seven days; rebuilding from Xcode resets the clock. The paid tier ($99/year) removes that limit and is what you need to ship to anyone else.
- A free 511.org API key. [Get one here](https://511.org/open-data/token).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). It generates the Xcode project from `project.yml`.

## Setup

### 1. Clone

```bash
git clone https://github.com/integralhero/bay-area-train-widget.git
cd bay-area-train-widget
```

(Use your fork's URL if you've forked the repo.)

### 2. Set your Apple Developer Team ID

Copy the example xcconfig and fill in your team ID:

```bash
cp Configs/Local.xcconfig.example Configs/Local.xcconfig
```

Then edit `Configs/Local.xcconfig` and replace `YOUR_TEAM_ID_HERE` with your Apple Developer Team ID. You can find yours at https://developer.apple.com/account#MembershipDetailsCard.

`Configs/Local.xcconfig` is gitignored, so your team ID never lands in version control.

### 3. Choose your own bundle ID and app group

Apple won't issue a code-signing profile for someone else's bundle ID, so you need unique ones even if you only plan to run the app on your own device.

Open `project.yml` and `Shared/UserDefaultsStore.swift`. In both files, replace:

- every occurrence of `com.trainwidget` with your reverse-DNS prefix (e.g. `com.yourname`)
- every occurrence of `group.com.trainwidget.app` with a unique app group identifier (e.g. `group.com.yourname.trainwidget`)

Don't edit the `.entitlements` files directly. They're regenerated from `project.yml` each time XcodeGen runs.

If you want a different on-screen app name, also change `CFBundleDisplayName` in `project.yml`'s `info.properties` block.

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
1. Select the `TrainWidget` scheme and your iPhone (or the simulator).
2. Hit Cmd+R to build and run.
3. Grant location permission when iOS asks on first launch.
4. In the **Setup** screen, paste your 511.org API key.

If signing fails the first time you build, click each target (TrainWidget and TrainWidgetExtension) in Xcode's project navigator, go to **Signing & Capabilities**, and make sure your team is selected. Xcode registers the bundle ID and app group with Apple on your behalf.

### 6. Add the widget

After the app installs at least once, the widget shows up in iOS's widget gallery.

- **Home screen**: long-press an empty area, tap **+** in the top corner, search for "Bay Area Train Widget", pick a size, then **Add Widget**.
- **Lock screen**: open **Settings → Wallpaper → Customize → Lock Screen**, tap a widget slot, then pick Bay Area Train Widget.

### 7. Pick your lines

In the app, toggle on the agencies you ride. Tap line chips to star the ones you actually take. Starred lines get priority on the lock screen widget. With nothing starred, you'll see everything.

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
