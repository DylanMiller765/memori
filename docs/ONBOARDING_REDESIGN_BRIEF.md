# Onboarding Redesign Brief — v2.0 (Codex handoff)

This is a self-contained brief for redesigning **3 onboarding screens** in Memori (iOS SwiftUI app, brain training + screen-time blocker, soft-renaming to "Memo"). Read this whole doc before designing.

## What you're designing

Three screens within the existing 12-page onboarding flow. Current versions look like an iOS Settings page (vertical pill list with same-weight colored-square icons). Need a complete visual + copy redesign — *not* iteration on the existing pattern.

Two prior Claude Design rounds returned variations that kept reverting to the same icon-in-tile + boxed-card pattern we're trying to escape. This brief includes the specific anti-patterns that came back so you don't repeat them.

## App context (one paragraph)

Memori (renaming to **Memo - Doomscroll Blocker**) is the only iOS app that combines brain-training games with a screen-time blocker — distracting apps stay shielded until you complete a brain-training session. Single Pro tier ($6.99/mo, $39.99/yr, 3-day annual trial). Audience is Gen Z / younger users whose attention and memory feel fried from social media. Brand is anti-social-media-giants, irreverent, sharp. Mascot is **Memo** (a brain). Voice samples already in product: "MEMO ON PATROL," "bribe memo," "Bro is COOKED," "Caught in 4K." NOT wellness, NOT clinical, NOT preachy.

## Sister docs (read these too)

- **Visual system:** `docs/DESIGN.md` — color tokens, modifiers, components, mascot inventory, dark-mode-only surfaces
- **Brand voice:** auto-memory `project_brand_voice.md` — copy rules, line bank, do-say/don't-say, **the "informed fear + defiance" mode** that powers the new onboarding direction
- **Brand identity:** auto-memory `project_brand_identity.md` — positioning, dual-promise USP, competitor framing
- **Existing paywall design (v9-finch):** `Views/Paywall/PaywallView.swift` — match this energy for tone consistency

## Voice rules — short version

Full rules in `project_brand_voice.md`. The minimum to know:

1. **Informed fear + defiance**, always stacked. Every fear-stat ("$57B spent on engagement engineering") pairs with an agency line ("Memo levels the field" / "You're not weak. You're outgunned.").
2. **Punch the system, never the user.** Frame the user as outgunned, not addicted. "By design" framing — the apps work as intended, you're not broken.
3. **Name apps when it lands** — "social media giants" / "the algorithm" / "the system" still work for broad claims, but product UI may name TikTok, Instagram, YouTube, Snap, etc. when concreteness makes the line sharper.
4. **Round defensible numbers.** $57B not $57.43B. 50,000 A/B tests not "many tests."
5. **Never wellness-speak.** No "digital wellbeing," "mindfulness," "intentional tech use." The vibe is gen-z + slightly pissed off + funny + competitive.
6. **One stat per screen max.** Stacking becomes a lecture. Drop-off jumps.

The unlock line that captures the whole posture: **"You're not weak. You're outgunned."**

## The escalation pattern (across onboarding)

Three stat moments, escalating in scope. Each different emotional beat. Don't repeat the same beat three times.

1. **Scare page (page 4):** *industry-level* — "$57B spent engineering this. The algorithm isn't broken — it's working as designed." → **fear**
2. **Empathy interstitial (post-goals):** *personal-level* — "You're not weak. You're outgunned." → **validation + defiance**
3. **Plan reveal shock-stat:** *life-level* — "44,000 hours. 5 years of your life." → **defiance + commitment**

This brief covers screens 2 and 3 of the escalation. Screen 1 (the upgraded scare page) is a future project.

## Design tokens (Memori dark-mode v2.0)

```
Page bg          #0A0A0F
Surface          #14141F  (white@8% borders)
Brand blue       #6890FE  (CTA + selected)
Brand deep       #4A7FE5  (gradient end)
Memo purple      #B857F5
Coral / danger   #FA6B59
Amber / warning  #FFC247
Mint / success   #00D19E
Text primary     white@94%
Text secondary   white@62%
Text tertiary    white@40%

Type: Inter (UI), JetBrains Mono (numerals — required for all numbers)
Corner radii: 14–26pt, no sharp corners
Pin .preferredColorScheme(.dark) on all 3 screens — these are dark-only by design
```

## Mascot inventory + mission poses

| Asset | Vibe | Best for |
|---|---|---|
| `mascot-thinking` | Pondering, considered, slight tilt | Empathy beat (calm wisdom variant) |
| `mascot-goal` | Determined, ready-to-fight, eyes forward | Empathy beat (defiant variant) — recommended |
| `mascot-low-score` | Sad, slumped | Scare page; could work as "before Memo" reference |
| `mascot-unlocked` | Celebrating, fists up | Plan reveal celebration moment |
| `mascot-locked-sad` | Defeated | Exit offer sheet (used elsewhere) |
| `mascot-welcome` | Waving, friendly | Onboarding welcome (already used) |
| `mascot-lookout` | Stealth / patrol / catching the feed | Feed Heist goals screen — newly approved mission pose |

**Critical:** Mascot PNGs render with transparent backgrounds. Place them directly on the dark page — **never on a white container or checkered transparency placeholder.** A previous design round shipped Memo on a checkered PS-transparency pattern; that's a render bug, not a design.

**New rule:** new Memo mission poses are allowed when an existing mascot cannot carry a key emotional beat. They must preserve the recognizable Memo anatomy and palette: blue brain body, thick purple outline, pink neural folds, glasses, two arms max unless deliberately documented, and no off-model extra limbs. Use new poses sparingly for hero beats, not as decoration on every page.

---

# Screen 1 — Goals selection

**Function:** user picks 1–3 from 6 pain-point options.

**Options:**
1. My screen time is out of control
2. I doomscroll way too much
3. I can't focus like I used to
4. I lose my train of thought easily
5. I forget things too quickly
6. I want to stay mentally sharp

**Direction:**

- Multi-select, **one screen** (do not split into Noom-style multi-page — adds drag without enough conversion lift at this stage)
- **Drop the icon-tile pattern entirely.** Two valid approaches:
  - (a) Large emoji at 36–40pt floating in the card body (no colored square behind it). Suggested: 📱💀 / 🌀 / 🫥 / 🌫️ / 🧠💭 / ⚡ — but emoji rendering on iOS SwiftUI is finicky; verify each renders correctly in the system font on a dark background. The "screen time" emoji in a previous round rendered as a checkered transparency placeholder (broken).
  - (b) **No emoji at all.** Lean entirely on bold typography + a subtle leading accent dot or color block. Cleaner, less risk of emoji rendering bugs, more editorial.
  - **Pick (b) if (a)'s emoji rendering is unreliable.** No middle ground (no "small icon in tile" — that's exactly the AI-slop pattern we're escaping).
- Reduce visual weight of unselected cards. Selected state should pop hard with brand blue + glow + filled checkmark (this part worked in a previous round — keep).
- Headline: **"What's wrecking your brain?"** (combative, on-brand, question-form invites confession). Tweak variant: **"Pick your poison."** (cocky, gen-z).
- Subhead: "Tap up to 3. We'll calibrate your training around what's broken." or similar
- CTA: **"Build my plan"** (not "Continue" — match verb to moment)
- Page-dot indicator visible at bottom (this is still a funnel-input page)
- Optional eyebrow: "STEP 03 — DIAGNOSIS" type label at the top — gives the screen a sense of place. A previous round did this and it worked.

---

# Screen 2 — Empathy interstitial (NEW screen, post-selection)

**Function:** the empathy beat. Reframes the user's confessions ("yeah I doomscroll") into "you're not the problem; the system is." Recruits the user into a side. This screen *must feel completely different from screen 1* — it's the emotional moment, not an input.

**Direction:**

- **Full-bleed editorial.** Big type, generous whitespace, mascot present. Not a card; not a panel; not contained chrome.
- **Mascot:** `mascot-goal` (determined, ready-to-fight). Place directly on the dark page — no white box, no checkered placeholder. Subtle entrance animation (fade up + slight scale-in).
- **Headline (mixed weight, two-color):**
  - Line 1: **"Your brain isn't broken."** (white)
  - Line 2: **"It's been hijacked."** (brand blue)
  - This split-color pattern worked in a previous round — keep it.
- **Sub-line:** *"47 apps are fighting for your attention every minute. Memo's gonna fight back with you."* (specific, brand-on, paired fear+defiance — already validated as one of the strongest copy moments we've landed)
- Tweak variant for the headline: **"You're not the problem. The algorithm is."** (your sample, blame-shift)
- CTA: **"Show me my plan →"**
- **Hide the page-dot indicator** if possible — this is a peak emotional moment, dots compete with drama. (Optional — if technically simpler to keep, keep.)

---

# Screen 3 — Plan reveal ("Your plan")

**Function:** the payoff. The user invested time picking goals and felt validated by the empathy beat. Now they see *the cost of not acting* and *the prescription for fighting back*. This is the climactic moment before paywall.

**Three vertical layers, top to bottom:**

### Layer 1 — Shock-stat hero (the "without Memo" panel)

- **Full-bleed**, edge-to-edge — *not contained in a polite padded card*. The number should EAT the screen width. A previous round put it inside a small panel; that's the wrong scale.
- Coral / amber tint background (signals danger / decay)
- Eyebrow: "WITHOUT MEMO" (small caps, tertiary text)
- Headline: One sentence, sharp. e.g. *"Here's what's at stake."* — keep it short. Don't lecture.
- **The number:** **44,000** in JetBrains Mono at 80–100pt+ (cinema scale). Should dominate the viewport.
- Unit/subtitle below the number (smaller mono): "HOURS · 5 YEARS OF YOUR LIFE"
- Animated count-up on entrance — number scrolls from 0 to 44,000 over ~1.5–2s. This is the Opal Focus Report energy.

### Layer 2 — The flip (the "with Memo" panel)

- Full-bleed, brand-blue tinted background
- Eyebrow: "WITH MEMO"
- Headline: *"Memo cuts this in half."* or *"Reclaim 4 years."*
- The number: **11,000** in same JetBrains Mono treatment. Animated transition — bad number morphs/crossfades into the good number is the most cinematic option (most TikTok-screenshottable). Side-by-side split is the boring option.
- Unit/subtitle: "HOURS · 4 YEARS BACK"

### Layer 3 — The plan card (the prescription)

- A single card *below* the two stat panels — small, supporting, not the hero
- **Medium clinical-ness — NO faux-medical chrome.** A previous round shipped "Your Prescription / The Memori Protocol / RX-072 v.1" — this is doctor cosplay and we explicitly rejected it. *No "Rx" glyph, no "v.1," no version numbers, no signature lines, no fake medical chart aesthetic.*
- Use mono numerals + hairline rules + numbered items for the "calculated, not configured" feel. That part is right.
- **Header:** "The plan." or "Memo's plan." or "Your fight plan." — brand voice, not pharmacy voice.
- **Four rows** (placeholder data, render plausibly):
  - `01 · DAILY TRAINING` → `5 min`
  - `02 · APPS LOCKED` → `[count from goals]`
  - `03 · DAILY UNLOCKS EARNED` → `3×`
  - `04 · WEEKLY LEADERBOARD` → `unlocks Day 5`

The 4th row teases the **Competition** brand pillar — leaderboards are how Memo turns brain training into a sport instead of a chore. Without it, the user finishes onboarding without ever knowing leaderboards exist (they live in the buried Compete tab). The "unlocks Day 5" framing creates a forward-looking commitment moment ("come back to compete").

Tweak variant: if 4 rows visually overcrowds the card, replace with 3 rows + a one-line callout below the card: *"Plus: weekly + monthly leaderboards. Compete with everyone training."*

### Plan reveal CTA + chrome

- CTA: **"Start my training →"** or **"Get my plan"** (continues into the existing v9-finch paywall — that's the next screen, do not redesign the paywall)
- **Hide page-dot indicator** — this is the climax
- **Do not include the App Store testimonial card.** It already lives on the paywall (next screen). A previous round dropped it as a floating sidekick under the plan; that's the lazy-design tell we're avoiding.

---

## Anti-patterns (specific things prior rounds shipped that we do NOT want)

1. **"RX-072 v.1" / "Your Prescription" / "The Memori Protocol"** — full faux-medical chrome on the plan card. We picked "Medium clinical-ness" specifically to avoid this. No version numbers, no Rx glyphs, no doctor LARP.
2. **Mascot on a white checkered transparency background** — that's the Photoshop "no image" placeholder showing through. Mascot goes on the dark page directly.
3. **Same icon-tile pattern with emoji subbed in** for SF Symbols on the goals page. The whole point was breaking the icon-tile idiom — same shape with different content is still the same shape.
4. **Stat panels contained in small padded cards** on the plan reveal — kills the cinema. Should be full-bleed.
5. **"The math, before and after Memori"** as the plan-reveal headline — too gentle, lost the brand voice. "Here's what's at stake" / "Without Memo / With Memo" is sharper.
6. **Floating App Store testimonial card** under the plan reveal cards — feels bolted on; testimonial belongs on the paywall.
7. **Page dots showing on the plan reveal** — this is the climax, dots compete with drama.
8. **Two competing progress systems** (e.g., "2/3" counter top-right AND 11 dots at bottom). Pick one.

## What's already locked (don't re-litigate)

- Headline copy on screens 1 and 2 — rationale documented in the brand voice doc
- Three-layer structure of screen 3 (shock stat → flip → plan card). Don't propose alternatives like "single shock stat only" or "no shock stat, just plan card."
- Hide page dots on screen 3, keep on 1–2
- New Memo mission poses are allowed for key onboarding moments, with strict palette/anatomy rules
- Dark mode only — these screens pin `.preferredColorScheme(.dark)`
- iPhone only (no iPad concerns)
- Specific consumer app names are allowed when they make the screen more concrete; avoid legalistic parent-company callouts unless the stat requires them

## Output expected

- Clickable iOS prototype with all 3 screens + transitions (so the FLOW between screens can be felt, especially the empathy beat which only lands in context)
- 2 variations per screen as Tweaks (toggleable) for the few decisions where 2 directions both could work — flagged in this brief as "Tweak variants"
- Export bundle ready for SwiftUI implementation — prefer simple HTML/CSS/JS prototype over Figma if possible (matches how the Memori paywall was implemented from a Claude Design export earlier in the project)

## Reference apps (look at these before designing)

- **Opal "Focus Report"** — for the shock-stat treatment. Single screen, big number, full-bleed. Don't put it in a card. Search "Opal focus report screenshot."
- **Cal AI macro reveal card** — for the mono-numerals + hairline-rules aesthetic on the plan card. NOT the Rx-pad LARP, just clean mono nutrition-label feel.
- **Noom plan projection chart** — for the count-up cinema treatment. Animated, dramatic, the moment of revelation.
- **Existing Memori paywall (`Views/Paywall/PaywallView.swift`)** — the v9-finch design. Match this energy for tone consistency. The mascot + confetti + dark surface + brand-blue CTA is the visual language to extend.

## Final tone check

When you're done, ask: "Would a 22-year-old who just deleted TikTok for the third time this month screenshot this and send it to a friend?" If yes, ship it. If it sounds like a wellness app — or worse, a doctor's office — rewrite it.

---

## Appendix — brand voice across the rest of onboarding (downstream context, not part of this redesign)

Codex is only designing the 3 hero screens above (goals / empathy / plan reveal). The other 9 onboarding pages already exist in code. They'll get a copy refresh during the upcoming "Memori → Memo" string sweep, **NOT** as part of this design pass.

This appendix exists so Codex knows the surrounding flow's intended brand-voice landing points. The 3 hero screens you're designing should fit naturally into this arc.

The full 12-page flow (the existing sequence + the planned voice landings):

| # | Page | Role | Brand voice landing |
|---|---|---|---|
| 0 | Welcome | Open with the pitch, not the greeting | *"Built to fight what's eating your attention." / "From a developer who couldn't put down TikTok either."* |
| 1 | Name | Friendly intake | Light, neutral. Don't waste it on posture; let the user breathe before the heavy beats. |
| 2 | **Goals** *(Codex designs this)* | Confession | *"What's wrecking your brain?"* + emoji or bold-type cards |
| 3 | Age | Personalize the threat using their input | *"By [age], the average phone has stolen [X] hours of your life."* |
| 4 | Scare | Industry-level fear stat | *"$57B engineering this. The algorithm isn't broken — it's working as designed."* OR *"$700B in ad revenue says you're not the customer. You're the inventory."* |
| 5 | Quick Assessment | Brain age test | Neutral. The stakes were already established on page 4; let the test feel like a measurement, not another sermon. |
| — | Brain age reveal *(fullScreenCover)* | Personal payoff | Existing dramatic reveal — keep |
| 6 | **Personal Solution** *(after reveal — currently exists in code)* | Mirror back goals as solutions | Voice refresh: more brand-voice-on, less "Your plan" wellness-app neutral. Could include a **leaderboard tease** if not already in screen 3's plan card: *"You'll compete on weekly + monthly leaderboards. Other brains doing the same thing."* |
| 7 | Notification Priming | Permission request | Reframe in brand voice: *"Memo's gonna fight back. Want a heads-up when it does?"* |
| 8 | Stat 144× | Personal-level cost | *"144 times a day you check your phone."* / *"47 apps fighting for your attention."* — combine the time-cost and the data-cost framing. |
| 9 | Personal Unlocks (287×) | Anchored Focus Mode pitch | *"287 times you'll unlock Memo's blocked apps this month. Each one earned."* |
| 10 | Focus Mode setup | Tactical setup | Functional, but copy hits should land Memo-as-bouncer voice — not "select apps to block" but *"Pick what Memo bounces."* |
| 11 | Commitment | Sign the contract | *"I'm committing to fight back."* — the verb matters. Not "I'll train daily." This is the user joining the side. |

**The pattern:** every page that has body copy gets a brand-voice line, even if it's a single phrase. By page 11 the message has hit the user 6+ times in different beats. They cannot forget what they signed up for.

**Where leaderboards fit:**
- **Primary tease:** in screen 3's plan card (4th row — see Layer 3 spec above), or as a callout below the card
- **Secondary mention:** in the Personal Solution page (6) when it gets its copy refresh — could include a leaderboard line in the mirror-back section
- **Tertiary:** Commitment page (11) — could include leaderboard rank in the contract bullets

These are all post-design-pass concerns. Codex doesn't need to touch them — but Codex's screen 3 design SHOULD include the leaderboard tease (4th row or callout) so the rest of the flow has something to build on.
