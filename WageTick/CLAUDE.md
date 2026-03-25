# WageTick — Project Reference

## What It Is
iOS + watchOS app for tracking hourly shift earnings. Supports real-time earnings tickers, department-split shifts, recurring weekly shifts, and earnings stats. Built with SwiftUI + SwiftData.

---

## Data Models

### `Shift`
Core model. Key fields:
- `hourlyWage: Decimal` — base rate (fallback when no segment department)
- `startTime / endTime: Date`
- `unpaidBreakDuration: TimeInterval`
- `recurringSeriesID: UUID?` — nil = standalone; shared UUID = recurring series
- `recurringSeriesIndex: Int?` — 0 = template, 1..n = generated occurrences
- `breakSegmentIndex: Int?` — which segment absorbs the unpaid break deduction
- `segments: [ShiftSegment]` — cascade delete

Computed:
- `isOngoing / isScheduled / isCompleted` — status flags
- `earnedSoFar(now:)` — real-time earnings (handles segments + break)
- `totalShiftPay()` — final earnings
- `sortedSegments` — segments sorted by `sortOrder`
- `needsDepartmentSegments` — true when recurring shift has no segments set
- `needsBreakSegmentAssignment` — true when break exists but no segment designated

### `ShiftSegment`
One time block within a shift.
- `department: Department?` — nullify on delete; nil = use shift's base wage
- `durationMinutes: Int`
- `sortOrder: Int`
- `shift: Shift?` — back-reference
- `effectiveRate(fallbackWage:)` — returns dept rate or fallback

### `Department`
- `name: String`
- `hourlyRate: Decimal`
- `isActive: Bool`
- `isBaseRate: Bool` — only one can be true at a time; enforced in `DepartmentFormView.save()`

### Relationships
```
Shift → [ShiftSegment]  (cascade delete)
ShiftSegment → Department  (nullify on delete)
```

---

## Earnings Calculation

**Single-rate shift:**
```
earned = (shiftDuration - breakDuration) × hourlyWage / 3600
```

**Multi-segment shift:**
- Walk segments in order
- For designated break segment: `paidFraction = max(segDuration - breakDuration, 0) / segDuration`
- Each segment: `earnings += segHours × segRate × paidFraction`
- Non-break segments: `paidFraction = 1.0`

Real-time (`earnedSoFar`): same logic but clamped to elapsed time.

---

## File Map

| File | Purpose |
|------|---------|
| `Shared/Shift.swift` | Core model + all pay calculations |
| `Shared/ShiftSegment.swift` | Time block within a shift |
| `Shared/Department.swift` | Department / pay rate |
| `Shared/WageManager.swift` | Observable 60fps timer for real-time earnings |
| `Shared/RecurringShiftGenerator.swift` | Generates + extends weekly recurring series |
| `Shared/SharedModelContainer.swift` | SwiftData setup, App Group, schema recovery |
| `ContentView.swift` | TabView + ShiftsView + SettingsView + NewShiftFormView + ShiftRowView |
| `ShiftTickerView.swift` | Active shift detail: live earnings ticker, segment breakdown |
| `ShiftFormView.swift` | Edit existing shift (sheet from ShiftTickerView) |
| `SegmentEditorView.swift` | Reusable segment editor used in both shift forms |
| `DepartmentsView.swift` | Department CRUD list + DepartmentFormView |
| `StatsView.swift` | Aggregated earnings stats + per-department breakdown |
| `NotificationManager.swift` | Shift start/end/department-reminder notifications |
| `WageTickApp.swift` | App entry, onboarding, extendIfNeeded call |
| `WageTickWatch Watch App/ActiveShiftsView.swift` | Watch: lists ongoing shifts |
| `WageTickWatch Watch App/ShiftRingView.swift` | Watch: circular progress ring detail |

---

## Navigation Structure

```
WageTickApp
├── DepartmentOnboardingView (first launch, sheet)
│   └── → DepartmentsView(showDoneButton: true)
└── ContentView (TabView)
    ├── ShiftsView (Shifts tab)
    │   ├── Section: Ongoing
    │   ├── Section: Upcoming  (recurring series → next occurrence only)
    │   ├── Section: Completed
    │   ├── Sheet: NewShiftFormView → SegmentEditorView → DurationPickerSheet
    │   └── Detail: ShiftTickerView → Sheet: ShiftFormView → SegmentEditorView
    ├── StatsView (Stats tab)
    └── SettingsView (Settings tab)
        └── NavigationLink → DepartmentsView(showDoneButton: false)
```

---

## Key Behaviours & Rules

**Recurring shifts:**
- `generate(from:into:)` tags the template as index 0 and creates 8 more weekly occurrences (indices 1–8) starting 1 week later. The template is never duplicated.
- `extendIfNeeded()` called on launch; extends series when <2 future weeks remain.
- Deleting a recurring shift: confirm single vs. entire series.
- Upcoming section deduplicates recurring series to show only the next occurrence.

**Department segments:**
- `SegmentEditorView` uses `DraftSegment` (transient) during editing; parent commits to SwiftData on save.
- Add/Done button disabled when `allocatedMinutes ≠ totalShiftMinutes`.
- Only one `isBaseRate` department allowed; `DepartmentFormView.save()` clears others.
- `DurationPickerSheet` uses `.wheel` DatePicker, minimum 15 minutes.

**Notifications (iOS only, `#if os(iOS)`):**
- Shift start: fires at `startTime`
- Shift end: fires at `endTime` with earnings summary
- Department reminder: fires 2h before each recurring shift (remind user to set departments)

**ShiftRowView layout (3–4 rows):**
1. Rate or "Split shift" label + earnings
2. Department pills (only when segments exist)
3. Date + recurring badge + status
4. "Set departments" warning (only when `needsDepartmentSegments`)

---

## Storage

- **App Group:** `group.danielmorgan.WageTick` → `wagetick.sqlite`
- Shared between iPhone and Watch apps
- Falls back to `ApplicationSupportDirectory` if App Group unavailable
- **Schema mismatch recovery:** deletes `.sqlite`, `.sqlite-shm`, `.sqlite-wal` and recreates

---

## Patterns & Conventions

- `Decimal` for all money values (never Float/Double)
- `NSDecimalNumber(decimal:).doubleValue` for display formatting only
- `@Observable` for view models (`WageManager`, `ShiftTickerViewModel`)
- `TimelineView(.periodic(from:by:))` for efficient periodic UI updates
- `pageSize = 3` per section with "Show More" pagination
- `showDoneButton: Bool = false` parameter on `DepartmentsView` — true only from onboarding
- `DraftSegment` pattern: transient struct for editing before committing to SwiftData
- `@AppStorage("hasSeenDepartmentOnboarding")` for one-time onboarding gate

---

## Watch App

- Read-only; no shift creation/editing
- Shares same SwiftData store via App Group
- `ActiveShiftsView`: lists ongoing shifts (start ≤ now < end), carousel style
- `ShiftRingView`: circular progress ring, earnings centre, 1s update interval

---

## Monetisation — StoreKit (INCOMPLETE / BLOCKED)

A £0.99 one-time "Support the Developer" IAP locks premium stats behind a paywall.

**Files:**
- `StoreManager.swift` — `@Observable` class, `Product.products(for:)`, `purchase()`, `restore()`, `UserDefaults` persistence (`premiumUnlocked`)
- `Products.storekit` — local StoreKit config, product ID: `com.danielmorgan.WageTick.unlock`, Non-consumable, £0.99, GBR storefront
- `StatsView.swift` — free tier always shown; premium tier behind `store.isUnlocked`; `PremiumUpsellCard` with buy + restore buttons
- `WageTickApp.swift` — `@State private var storeManager = StoreManager()` passed via `.environment(storeManager)`

**Free stats:** Total Earned, This Week/Month, Hours Worked
**Premium stats:** Averages, Break Deductions, Best Shift, Department Breakdown

**Current blocker: known Xcode 26 beta bug — local StoreKit testing is broken**
- Apple Developer Forums confirm this is a known Xcode 26 beta issue
- The scheme editor writes a malformed relative path (`../../WageTick/Products.storekit`) that resolves inside the `.xcodeproj` bundle rather than to the actual file
- `Product.products(for:)` always returns an empty array as a result
- `StoreView` also fails for the same reason
- No workaround exists; will be fixed in a later Xcode 26 beta or the stable release
- `#if DEBUG` Force Unlock button in StatsView lets you test the locked/unlocked UI in the meantime
- Real purchase flow will work once App Store Connect account is set up and tested on device via sandbox
