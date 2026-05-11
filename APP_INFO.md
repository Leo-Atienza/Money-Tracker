# Money Tracker — Application Overview & Design Brief

**Package name:** `budget_tracker`  
**Marketing name:** Money Tracker  
**App title (UI):** Money Tracker  
**Description (from project):** A minimalistic money tracking app  
**Current version:** See `pubspec.yaml` → `version:` (e.g. 4.4.0+build).

This document describes what the app does **and** everything typically needed to **design a new visual system and flows** (information architecture, navigation, tokens, patterns, states, and constraints).

---

## What this app is

Money Tracker is a **local-first** Flutter app for recording and understanding personal money flow. There is **no remote backend**: data stays on the device in **SQLite** (`sqflite`). State is coordinated with **Provider** (`AppState`).

The UI follows **Material 3** (`useMaterial3: true`), with **light / dark / system** theme modes and tooling aimed at **accessible contrast** (semantic money colors derived from WCAG-oriented helpers).

---

## Core functions

### Money in and out

- **Expenses** — Add, edit, and organize spending by category, date, and optional tags. **Partial payments** with progress and remaining amount.
- **Income** — Record income for the current account and period.
- **Accounts** — Multiple accounts; a **current account** scopes transactions, balances, and data.
- **Month-centric home** — Spending for a selected month; **horizontal swipe** changes month; **pull-to-refresh** reloads; month label opens picker; long-press month jumps to today.

### Planning and recurring items

- **Budgets** — Limits by category (full screen; also reachable from onboarding-style flows and home shortcuts where implemented).
- **Recurring expenses** — Auto-create monthly expenses; notifications optional.
- **Recurring income** — Auto-create monthly income.
- **Quick templates** — One-tap templates for common expenses.

### Organization

- **Categories** — User-defined categories with **colors** (used in lists, optional card tints).
- **Tags** — Filtering and organization in data model and history flows.
- **Trash** — Restorable deleted items (**30-day** window per settings copy).

### History, search, and analysis

- **History** — Separate tabs for **expenses** and **income**; search; category filter; **advanced filters** (date range, amount range, paid status); optional **all-time** mode with **infinite scroll** (pagination with a capped max for memory).

### Insights

- **Analytics** — Charts and written insights (e.g. month-over-month) using **`fl_chart`**.

### Data portability and safety

- **Export** — **CSV** export of transactions (settings subtitle reflects this).
- **Backup & restore** — Local backup files / restore pipeline.
- **PIN lock** — Optional app PIN; **fullscreen unlock** sheet; auto-lock on background; inactivity timer reset on interaction; app can exit if unlock dismissed.

### Notifications

- **Local notifications** — Bill reminders, budget alerts, optional monthly summary; dedicated **Notification Settings** screen.

### First run and diagnostics

- **Onboarding** — Shown until completed (`OnboardingService`); blocks main shell until done.
- **Crash log** — On-device error history for support (Advanced section).

### Platform extras

- **Home screen widget** — Updates when app backgrounds (where supported).

---

## Design brief: goals for a new look & feel

| Goal | Notes |
|------|--------|
| **Clarity** | Finance data must scannable at a glance: amounts, paid vs unpaid, month context. |
| **Trust & calm** | Minimal chrome; avoid noisy decoration; consistent number formatting. |
| **Speed** | Quick add, templates, recurring automation—flows should stay short. |
| **Accessibility** | Respect large text; WCAG-oriented status colors; minimum **48×48** touch targets (see tokens). |

**Brand personality (current direction):** Minimal, neutral “ledger” aesthetic—**not playful finance gamification**. Dark mode is a first-class citizen.

---

## Information architecture

### Primary shell (bottom navigation)

Four root tabs in an `IndexedStack` (state preserved when switching tabs). **Labels are hidden** on the bar (`NavigationDestinationLabelBehavior.alwaysHide`)—icons must read clearly.

| Tab | Screen | Icons (outline → selected) |
|-----|--------|----------------------------|
| 1 | **Home** | `home_outlined` → `home` |
| 2 | **History** | `history_outlined` → `history` |
| 3 | **Recurring** | `repeat` → `repeat_on_outlined` |
| 4 | **Settings** | `settings_outlined` → `settings` |

**Chrome:** Top border on nav bar (`outline` alpha varies by theme); bar height **65**; indicator uses **onSurface** at low alpha; background **surface**.

### Secondary / pushed screens (stack navigation)

**From Home (and elsewhere):**

- Add / edit **expense** (`AddExpenseScreen`).
- Add / edit **income** (`AddIncomeScreen`).
- **Add payment** dialog for partial payments (`AddPaymentDialog`).
- **Budget** surface (`BudgetScreen`) — also linked from Settings → Insights.
- **Advanced filter** dialog (`AdvancedFilterDialog`).

**From Settings (grouped sections—mirror in any new settings design):**

| Section | Destinations |
|---------|----------------|
| **Accounts** | Account picker (modal / flow)—current account name shown on tile. |
| **Appearance** | Theme mode (light / dark / system), **transaction card colors** toggle + **intensity slider** (0.1–1.0). |
| **Security** | PIN setup / management (`PinSetupScreen` embedded in `_PinSecurityCard`). |
| **Preferences** | Currency picker; **Recurring Expenses**; **Recurring Income**; **Categories**; **Quick Templates**. |
| **Insights** | **Budgets**; **Analytics**. |
| **Data & Backup** | **Trash**; **Backup & Restore**; **Export Data** (CSV). |
| **Notifications** | **Notification Settings**. |
| **Advanced** | **Crash Log**. |

**Auth / gate:**

- **PIN unlock** — `PinUnlockScreen` as **fullscreen dialog** over main shell when locked.

**Onboarding:**

- `OnboardingScreen` replaces shell until complete.

### Declared routes (deep links / internal)

- `/home` → main shell  
- `/onboarding` → onboarding  
- `/budgets` → `BudgetScreen`

### Notification-driven routing (behavior to preserve or redesign)

- Payload `recurring_expenses` → switch shell to tab index **2** (Recurring).  
- Payload `budget_alert:*` → tab index **0** (Home).

---

## User journeys (must remain design-complete)

1. **First launch** — Loading gate → onboarding → main shell → optional PIN unlock overlay.
2. **Daily check-in** — Open app → Home month summary → scroll transactions → pull to refresh.
3. **Log expense** — Home quick actions / category rows → add expense → optional partial payment later.
4. **Reconcile history** — History tab → search/filter → edit row → back.
5. **Month review** — Swipe or picker to change month; compare to budgets via Budget flow.
6. **Recurring maintenance** — Recurring tab or Settings → edit schedules.
7. **Insights** — Settings → Analytics (charts) / Budgets.
8. **Protect data** — Enable PIN → background app → unlock screen.
9. **Export / backup** — Settings → Export CSV or Backup & Restore.
10. **Account switch** — Settings → current account; **shell resets to Home tab** when account changes (product behavior).

---

## Visual design system (current implementation = baseline for redesign)

### Color

| Token / role | Implementation notes |
|--------------|------------------------|
| **Seed** | `ColorScheme.fromSeed(seedColor: 0xFF1E1E1E, brightness: …)` — neutral near-black seed for **both** themes. |
| **Light scaffold** | `#FAFAFA`. |
| **Dark scaffold / surface** | `#121212` (explicit `surface` in dark scheme). |
| **Cards** | Elevation **0**, corner **16**, **no** surface tint (`surfaceTintColor: transparent`). |
| **Inputs** | Filled fields; **12** radius; no visible border stroke (`BorderSide.none`). |
| **Semantic money colors** | `ThemeExtension<AppColors>`: **expenseRed**, **incomeGreen**, **warningOrange**, **infoBlue** — sourced from `ColorContrastHelper` **per brightness** (status colors). Use for amounts, badges, and optional chart accents. |

Designers should provide **light + dark** specs for all semantic states (paid, unpaid, partial, overdue if shown).

### Typography

Custom `TextTheme` built in `main.dart` (not only Material defaults):

| Style | Size | Weight (typical use) |
|-------|------|------------------------|
| displayLarge | 34 | w300 |
| headlineMedium | 28 | w300 |
| titleLarge | 20 | w600 |
| titleMedium | 16 | w500 |
| titleSmall | 15 | w500 |
| bodyLarge | 15 | w400 |
| bodyMedium | 13 | w400 |
| bodySmall | 11 | w400 |
| labelLarge | 14 | w600 |
| labelSmall | 11 | w600, letterSpacing **1.2** |

**Base text color** in this theme is **black vs white** depending on brightness (not only `onSurface`)—any redesign should reconcile with contrast on real colored surfaces.

### Spacing, radius, touch (canonical constants)

Defined in `lib/constants/spacing.dart`:

| Constant | Value (dp) | Use |
|----------|----------------|-----|
| tiny | 2 | Micro gaps |
| xxs | 4 | Inline tight spacing |
| xs | 8 | Small |
| sm | 12 | Compact blocks |
| md | 16 | Standard |
| lg | 20 | Card inner comfort |
| xl | 24 | Section spacing |
| xxl | 32 | Large gaps |
| xxxl | 40 | Hero sections |
| huge | 48 | Major separation |
| screenPadding | **24** | Page horizontal inset |
| cardPadding | 20 | Card bodies |
| minTouchTarget | **48** | WCAG touch minimum |
| radiusSmall / Medium / Large / XLarge | 8 / 12 / 16 / 20 | Chips, inputs, cards, sheets |
| iconSize / Large / Huge | 20 / 24 / 64 | Lists vs empty states |
| progressBarHeight | 8 / 4 | Payment progress |

### Transaction presentation patterns

- **Currency prefix** from settings (e.g. `$`) — amounts show **two decimal places** in key views.
- **Expense rows** — Primary amount in **expenseRed**; badges:
  - Unpaid / partial: **warningOrange** pill (“UNPAID”, “$X.XX left”).
  - Paid: **incomeGreen** pill (“PAID” + check icon).
- **Optional category tint** on cards — user toggle + **intensity slider** (affects subtle background on list rows).

### Motion & haptics

- **Tab change** — ~**200 ms** fade (`Curves.easeOut`); re-tapping same tab pops nested routes to root.
- **Haptics** — `HapticFeedback.selectionClick()` on tab change and some settings actions.
- **Month swipe** — Velocity threshold **500** (prevents accidental month change while scrolling quick-add horizontal areas).

---

## Components & building blocks (inventory)

Reusable UI in `lib/widgets/`:

- `CategoryTile` — category rows / chroma.
- `LoadingSkeleton` — loading placeholders.
- `ColorPicker` — category & accent picking.
- `AccessibleButton` — shared accessible button behavior.

**Navigation:** `PremiumPageRoute` used for polished page transitions to inner screens.

**Patterns elsewhere:** `SliverAppBar` + padded lists, settings **cards** with section headers, `SnackBar` (floating) for recurring auto-create feedback with **View** → jumps to History tab.

---

## Charts & analytics

- Library: **`fl_chart`**.
- Designer should spec **chart colors** for light/dark, **empty states**, and how **selected month** in `AppState` frames chart data.
- Screen: **Analytics** — expects scrollable vertical layout with multiple chart blocks + insight copy.

---

## Forms & dialogs

- **Amounts** — Decimal-safe logic in code; design should show **currency symbol + stable alignment** (tabular figures if branding allows).
- **Dates** — Month pickers, inline date fields, long-press “go to today” on home month label.
- **Modal bottom sheets** — Used heavily in **Settings** (pickers, confirmations).
- **Fullscreen dialogs** — PIN unlock.

---

## States designers must cover

| State | Where |
|-------|--------|
| **Cold start / loading** | Wallet icon + `CircularProgressIndicator` while onboarding flag loads. |
| **Empty lists** | Home category sections, History, Recurring, Budgets, Trash. |
| **Partial payment** | Progress bar under row (4 dp height); semantic progress labels for screen readers. |
| **PIN locked** | Numeric/alphanumeric PIN UI on `PinUnlockScreen`. |
| **Error / edge** | Crash log; snackbars for recoverable issues; notification init failure is non-fatal. |
| **Account switch** | Subtle reset-to-home (avoid jarring transition). |

---

## Accessibility & internationalization

- **Semantics** — `Semantics`, `AccessibilityHelper` labels on key controls (e.g. month navigation, payment progress).
- **Contrast** — `ColorContrastHelper` documents WCAG **AA** ratios (4.5:1 text, 3:1 large/UI); redesign should re-verify.
- **Locale** — `intl` + `initializeDateFormatting` — date formats follow user locale; **currency** is user-selectable (not device-locale-bound only).

---

## Platform & constraints

- **Orientation** — Portrait up/down only (`SystemChrome.setPreferredOrientations`).
- **No server** — No login UI, no social, no sync—omit from marketing designs unless product scope changes.
- **Distribution** — Android APK is a primary artifact (see `CLAUDE.md` for build/publish notes).

---

## File map for implementers

| Concern | Path |
|---------|------|
| Theme, app title, routes | `lib/main.dart` |
| Spacing / radius tokens | `lib/constants/spacing.dart` |
| Global state | `lib/providers/app_state.dart` |
| Screens | `lib/screens/` |
| Widgets | `lib/widgets/` |
| Contrast / semantic colors | `lib/utils/color_contrast_helper.dart` |
| Database | `lib/database/database_helper.dart` |

---

## Designer handoff checklist

Use this when shipping Figma (or equivalent) for a redesign:

- [ ] **Light + dark** page templates for: Home, History (both tabs), Recurring, Settings (all sections), Add Expense/Income, Budget, Analytics, Onboarding, PIN unlock.
- [ ] **Navigation bar** 4 destinations—icon-only bar height **65**; consider **label-on** variant for accessibility tests.
- [ ] **Semantic colors** spec’d for expense / income / warning / info + **paid vs unpaid** badges.
- [ ] **Spacing** scale aligned to **8px grid** and **24** screen horizontal padding (or deliberate deviation documented).
- [ ] **Type scale** table for all levels used in lists, headers, and analytics.
- [ ] **Charts** palette + grid/axis/label styles for `fl_chart` replacements.
- [ ] **Motion** notes: tab fade ~200 ms; optional reduced-motion variant.
- [ ] **Empty, loading, and error** frames for each primary screen.
- [ ] **Tap targets** ≥ **48×48** on primary actions.
- [ ] **Export** assets: adaptive icons, optional widget preview, notification icon if branded.

---

## Technical summary

| Area | Choice |
|------|--------|
| Framework | Flutter (Dart 3) |
| UI | Material 3 |
| State | Provider |
| Persistence | SQLite via `sqflite` |
| Money precision | `decimal` |

For build, release, and landing-page APK pipeline, see **`CLAUDE.md`**.
