# WageTick

A shift earnings tracker for iOS and Apple Watch. Log your shifts, track earnings in real time, and break down pay across multiple departments — all with a clean, native SwiftUI interface.

## Features

### Core
- **Live earnings ticker** — watch your pay accrue in real time at 60fps, down to 4 decimal places
- **Shift management** — log upcoming, ongoing, and completed shifts with start/end times
- **Unpaid break deductions** — configure break duration per shift; earnings adjust automatically without any sudden jumps
- **Recurring shifts** — repeat any shift weekly; generates 8 future occurrences, each independently editable

### Department Splits
- Split a shift across multiple departments, each with its own hourly rate
- Designate which segment absorbs the unpaid break deduction
- Per-department earnings breakdown in Stats

### Stats (Premium — £0.99)
- Weekly earnings bar chart with daily breakdown
- Average shift length and earnings per shift
- Unpaid break deductions as a percentage of gross earnings
- Best shift card
- Per-department hours and earnings totals

### Apple Watch
- Companion watch app showing active and upcoming shifts
- Live earnings ring updated via shared SwiftData App Group

### Settings
- Light / Dark / System theme
- Configurable week start day (Monday or Sunday)
- Shift start/end notifications
- Manage departments

## Requirements

| | |
|---|---|
| Xcode | 26 beta or later |
| iOS Deployment Target | iOS 26.2+ |
| Swift | 5.0 |
| Frameworks | SwiftUI, SwiftData, Swift Charts, StoreKit 2 |

## Building & Running

1. **Clone the repo**
   ```bash
   git clone https://github.com/dcm2610/WageTick.git
   cd WageTick
   ```

2. **Open in Xcode**
   ```bash
   open WageTick.xcodeproj
   ```

3. **Select a scheme and destination**
   - `WageTick` — iPhone simulator or device
   - `WageTickWatch Watch App` — Apple Watch simulator or device

4. **Run** with `Cmd+R`

> No third-party dependencies. No package manager setup required.

## In-App Purchases

The app uses StoreKit 2 for the £0.99 premium unlock. Local StoreKit testing via `Products.storekit` is currently broken in Xcode 26 beta (known Xcode bug — `Product.products(for:)` returns an empty array regardless of configuration).

**Workarounds:**
- A `#if DEBUG` "Force Unlock Premium" button is present on the Stats screen for local development
- Real purchase flow can be tested end-to-end using App Store Connect sandbox on a physical device

## Project Structure

```
WageTick/
├── Shared/
│   ├── Shift.swift                 # Core data model + earnings logic
│   ├── ShiftSegment.swift          # Department segment model
│   ├── Department.swift            # Department model
│   ├── WageManager.swift           # Live earnings publisher
│   ├── RecurringShiftGenerator.swift
│   └── SharedModelContainer.swift  # SwiftData + App Group setup
├── ContentView.swift               # Tab bar + Shifts list + New shift form
├── ShiftTickerView.swift           # Live earnings detail view
├── ShiftFormView.swift             # Edit shift sheet
├── SegmentEditorView.swift         # Department split editor
├── StatsView.swift                 # Earnings statistics
├── DepartmentsView.swift           # Department management
├── StoreManager.swift              # StoreKit 2 purchase handling
├── NotificationManager.swift       # Local push notifications
└── WageTickApp.swift               # App entry point + onboarding

WageTickWatch Watch App/
├── WageTickWatchApp.swift
├── ActiveShiftsView.swift
└── ShiftRingView.swift
```

## Architecture

- **SwiftUI + SwiftData** throughout — no UIKit, no Core Data
- **`@Observable`** for `StoreManager` and `WageManager` (no Combine)
- **App Group** (`group.com.danielmorgan.WageTick`) for sharing the SwiftData store between the iOS app and Watch extension
- **`Decimal`** used for all monetary arithmetic to avoid floating-point rounding errors
- Earnings tick in real time using a `Timer`-driven `WageManager` that publishes at 60fps

## License

MIT
