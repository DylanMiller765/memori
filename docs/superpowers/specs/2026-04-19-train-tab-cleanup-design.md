# Train Tab Cleanup — v1.4.2

## Problem
The Train tab has too many stacked banners (daily limit bar, daily challenge card, referral banner) before users reach the actual games. The "try each game once" feature has no clear communication mechanism.

## Changes

### 1. Referral Banner → Single-Line Row
**Current:** Full card with mascot image, text, and Share button.
**New:** A single tappable text row: "🎁 Invite a friend, get Pro free →"
- Sits between the daily challenge card and the first game category
- Tapping opens the same referral share sheet as the current banner
- Same purple/indigo accent styling but as inline text, not a card

### 2. One-Time "Free Play" Mascot Popup
A modal popup shown once on the first Train tab visit (for free users only):
- **Image:** `mascot-celebrate` asset
- **Title:** "Every game is free to try!"
- **Body:** "Your first play of each game doesn't count toward your daily limit. Go explore!"
- **Button:** "Let's go!" (accent gradient button)
- **Dismiss:** Tapping button or background dismisses. Sets `UserDefaults` flag `has_seen_free_play_popup = true`. Never shows again.
- **Trigger:** Shows when `!isProUser && !hasSeenFreePlayPopup` on Train tab appear.

### 3. Remove "Try Each Game" Text Hint
Delete the `✨ Games marked NEW get a free first play` text line under the daily limit bar. The popup replaces this.

### 4. Remove Share Buttons from Game Results (Done)
The `onShare` callback and "Share Result" button have been removed from `GameResultView` and all 10 game views.

### 5. Faster Result Animation (Done)
Reveal sequence cut from 2.0s to 1.1s. Score count animation cut from 1.0s to 0.5s.

## Files to Modify
- `ContentView.swift` — Replace `ReferralBannerView()` with inline row, add popup state/view, remove text hint
- `Views/Components/FreePlayPopup.swift` — New file for the one-time popup view

## Not Changed
- Daily limit bar — stays as-is
- Daily challenge card — stays as-is
- Game cards with NEW badges — stay as-is
- GameResultView share removal — already done
- Result animation speed — already done
