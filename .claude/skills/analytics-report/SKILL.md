---
name: analytics-report
description: "Pull and summarize TelemetryDeck analytics for Memori. Shows DAU, game popularity, paywall conversion, and actionable recommendations. Use when the user asks about analytics, metrics, 'how's the app doing', or '/analytics-report'."
---

# Analytics Report Skill

Pull analytics data from TelemetryDeck and present a summary report for the Memori app.

## Configuration

- **TelemetryDeck API base URL**: `https://api.telemetrydeck.com`
- **App ID**: `07CABBEB-051B-4AC3-937F-FD0A276D09C7`
- **Signal types tracked**: `exercise.completed`, `exercise.started`, `paywall.shown`, `paywall.converted`, `onboarding.completed`, `brainScore.completed`, `tab.viewed`, `share.tapped`, `streak.updated`, `dailyChallenge.completed`
- **Games**: Reaction Time, Color Match, Speed Match, Visual Memory, Number Memory, Math Speed, Dual N-Back, Chunking

## Instructions

### Step 1: Authenticate with TelemetryDeck

Check if the user has previously provided TelemetryDeck API credentials. If not, ask for them:

> To pull analytics from TelemetryDeck, I need your API credentials. You have two options:
>
> **Option A — Email & Password (generates a bearer token):**
> Provide your TelemetryDeck account email and password. I will call the login endpoint to get a bearer token.
>
> **Option B — Existing API Token:**
> If you already have a bearer token, paste it directly.
>
> Your credentials are only used for this API call and are not stored anywhere.

**To generate a bearer token (Option A)**, make a POST request:

```bash
curl -X POST "https://api.telemetrydeck.com/api/v1/users/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "<USER_EMAIL>", "password": "<USER_PASSWORD>"}'
```

The response contains a `token` field. Use this as the Bearer token for all subsequent requests.

### Step 2: Query Key Metrics

Use the TelemetryDeck Query API to pull data. All queries go to:

```
POST https://api.telemetrydeck.com/api/v3/query
```

With header: `Authorization: Bearer <TOKEN>`

Run the following queries. Execute them in parallel where possible for speed.

#### 2a. Total signals (last 7 days and last 30 days)

```json
{
  "appID": "07CABBEB-051B-4AC3-937F-FD0A276D09C7",
  "queryType": "timeseries",
  "granularity": "all",
  "relativeTimeInterval": "last7Days",
  "aggregations": [
    { "type": "count", "name": "totalSignals" }
  ]
}
```

Repeat with `"relativeTimeInterval": "last30Days"` for the 30-day total.

#### 2b. Unique users (last 7 days and last 30 days)

```json
{
  "appID": "07CABBEB-051B-4AC3-937F-FD0A276D09C7",
  "queryType": "timeseries",
  "granularity": "all",
  "relativeTimeInterval": "last7Days",
  "aggregations": [
    { "type": "thetaSketch", "name": "uniqueUsers", "fieldName": "clientUser" }
  ]
}
```

Repeat with `"relativeTimeInterval": "last30Days"`.

#### 2c. Signal breakdown by type (last 30 days)

For each signal type (`exercise.completed`, `exercise.started`, `paywall.shown`, `paywall.converted`, `onboarding.completed`, `brainScore.completed`), query:

```json
{
  "appID": "07CABBEB-051B-4AC3-937F-FD0A276D09C7",
  "queryType": "timeseries",
  "granularity": "all",
  "relativeTimeInterval": "last30Days",
  "filter": {
    "type": "selector",
    "dimension": "type",
    "value": "<SIGNAL_TYPE>"
  },
  "aggregations": [
    { "type": "count", "name": "count" }
  ]
}
```

#### 2d. Exercise completions by game (last 30 days)

```json
{
  "appID": "07CABBEB-051B-4AC3-937F-FD0A276D09C7",
  "queryType": "groupBy",
  "granularity": "all",
  "relativeTimeInterval": "last30Days",
  "filter": {
    "type": "selector",
    "dimension": "type",
    "value": "exercise.completed"
  },
  "dimensions": ["game"],
  "aggregations": [
    { "type": "count", "name": "completions" }
  ]
}
```

Repeat with `"value": "exercise.started"` to get starts by game (for drop-off calculation).

#### 2e. Daily active users (last 7 days, daily granularity)

```json
{
  "appID": "07CABBEB-051B-4AC3-937F-FD0A276D09C7",
  "queryType": "timeseries",
  "granularity": "day",
  "relativeTimeInterval": "last7Days",
  "aggregations": [
    { "type": "thetaSketch", "name": "uniqueUsers", "fieldName": "clientUser" }
  ]
}
```

Average the daily unique user counts to get avg DAU.

### Step 3: Calculate Derived Metrics

From the raw data, compute:

- **Paywall conversion rate**: `paywall.converted / paywall.shown * 100`
- **Onboarding completion rate**: `onboarding.completed / (unique users with no exercise.completed who triggered onboarding)` — approximate from onboarding.completed vs new unique users if possible
- **Start-to-completion drop-off per game**: `(exercise.started - exercise.completed) / exercise.started * 100` for each game
- **Avg games per user**: `total exercise.completed / unique users (30d)`
- **Estimated MRR**: `paywall.converted * weighted_avg_price` where weighted avg assumes 70/30 annual/monthly split: `(0.7 * 19.99/12) + (0.3 * 3.99)` = ~$2.36 per conversion per month. Multiply by total conversions in last 30 days. Note this is a rough estimate.

### Step 4: Present the Report

Format the output as follows:

```
## Memori Analytics Report — [start date] to [end date]

### Key Metrics
- DAU (7d avg): X
- Total signals: X (7d) / X (30d)
- Unique users: X (7d) / X (30d)
- Onboarding completions: X

### Engagement
- Most played game: [game] (X completions)
- Least played game: [game] (X completions)
- Avg games per user (30d): X
- Start-to-completion drop-off by game:
  - [game]: X% drop-off (X started, X completed)
  - [game]: X% drop-off
  - ...

### Revenue
- Paywall views (30d): X
- Conversions (30d): X
- Conversion rate: X%
- Estimated MRR: $X (assumes 70/30 annual/monthly split at 85% after Apple cut)

### Brain Score
- Brain score completions (30d): X

### Recommendations
- [Insight 1: e.g., "Reaction Time has 40% drop-off — consider simplifying the tutorial or reducing initial difficulty"]
- [Insight 2: e.g., "Paywall conversion is 2.1% — above average for casual games. Consider testing a lower price point to increase volume"]
- [Insight 3: e.g., "Chunking is least played — consider promoting it in the daily training rotation or improving discoverability"]
```

Tailor the recommendations to the actual data. Focus on actionable insights the developer can act on this week. Consider:
- Games with high drop-off may need UX or difficulty adjustments
- Low paywall conversion may indicate timing or pricing issues
- Imbalanced game popularity may suggest discoverability problems
- Low onboarding completion suggests friction in the first-run experience

### Step 5: Fallback (No API Access)

If TelemetryDeck API authentication fails or the user cannot provide credentials, instruct them:

> I was unable to authenticate with the TelemetryDeck API. Here is how you can get the data manually:
>
> 1. Go to **dashboard.telemetrydeck.com** and log in
> 2. Select the **Memori** app
> 3. Take a screenshot of the **Overview** page (shows signals, users, top signals)
> 4. Go to **Signals** and filter to the last 30 days — screenshot the signal list
> 5. Go to **Insights** if available and screenshot any charts
> 6. Share the screenshots with me and I will analyze them and build the report
>
> Alternatively, you can export data as CSV from the TelemetryDeck dashboard and paste the contents here.

When analyzing screenshots, use the same report format above. Extract as many numbers as are visible and note any metrics that could not be determined from the screenshots.
