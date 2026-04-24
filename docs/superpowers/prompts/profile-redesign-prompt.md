# Profile Tab Redesign Prompt

## Context
Branch: `v2.0-focus-mode`. The Profile tab is currently `MindRestore/Views/Settings/SettingsView.swift` which mixes user info with app settings. We're redesigning it to be a player card + achievements screen, with settings accessible via a gear icon.

## Design (from Claude Design mockup)

The new Profile screen layout (top to bottom):

### 1. Header
- Small caps "MEMORI / PROFILE" on left
- "v2.0 · PRO" badge on right (show actual version + subscription status)

### 2. Player Card (hero)
- Mascot avatar centered (use `mascot-cool` image, ~120pt)
- User's name large and bold below (`user.username` or "Player")
- Join date below in gray (derive from User model or use a stored date)

### 3. Three Stat Pills (horizontal row)
- **Level**: `user.level` with "LEVEL" label below
- **Streak**: `user.currentStreak` in green with "STREAK" label
- **Best Rank**: Replace "Global #247" with user's best personal best game. Use `PersonalBestTracker.shared`
- Separated by vertical dividers

### 4. XP Progress Bar
- Mascot-cool small icon on left
- Title name from `user.levelName` (e.g. "Memory Apprentice")
- XP progress bar (accent color)
- "XXX XP → [Next Level Name]" on right
- Use `UserLevel` to get current/next level info

### 5. Achievements Section
- Header: "ACHIEVEMENTS · X / Y" with "All →" link
- Show first 4-5 unlocked achievements as numbered rows
- Each row: number, achievement name (bold), description (gray), "UNLOCKED" badge (green capsule)
- Achievement data from `@Query private var achievements: [Achievement]`

### 6. Settings Button
- At the bottom, a gear icon button or "Settings" row that opens the existing settings as a sheet
- Move all the current SettingsView content (theme, notifications, subscription management, reset, debug tools) into this sheet

## Data Sources Available
```swift
@Query private var users: [User]  // user.username, user.level, user.currentStreak, user.totalXP, user.levelName
@Query private var achievements: [Achievement]  // achievement.title, achievement.subtitle, achievement.isUnlocked
@Environment(StoreService.self)  // storeService.isProUser, storeService.isUltraUser
@Environment(GameCenterService.self)  // for leaderboard data if needed
```

## Key Files to Reference
- `MindRestore/Views/Settings/SettingsView.swift` — current Profile tab (will be restructured)
- `MindRestore/Models/User.swift` — User model with level, streak, XP, levelName
- `MindRestore/Models/Achievement.swift` — Achievement model
- `MindRestore/Utilities/DesignSystem.swift` — AppColors, design system

## Style
- Dark background with `AppColors.pageBg` / `.pageBackground()`
- Monkeytype-inspired: clean stats, monospace numbers, uppercase tracked section headers
- Use `.system(size:weight:.bold, design: .rounded)` for numbers
- Section headers: `.font(.system(size: 11, weight: .bold))`, `.tracking(2)`, `.foregroundStyle(.secondary)`
- Achievement badges: green capsule with white "UNLOCKED" text
- The mascot should feel prominent — this is the user's identity screen

## Implementation Approach
1. Create a new `ProfileView.swift` in `MindRestore/Views/Profile/`
2. Move settings content from `SettingsView.swift` into a `SettingsSheet.swift` or keep SettingsView and present it as a sheet
3. Update `ContentView.swift` to use the new `ProfileView` instead of `SettingsView` for the Profile tab
4. Add new files to the Xcode project (pbxproj)

## After Building
- Build for device: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build`
- Install: `xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app`
