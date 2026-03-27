---
name: ship-testflight
description: "One-command App Store submission: bumps version, archives, uploads, creates version in ASC, sets what's new, attaches build, and submits for review. Use when the user says 'ship it', 'push to app store', 'submit for review', 'upload to testflight', or '/ship-testflight'."
---

# Ship to TestFlight / App Store

This skill automates the entire TestFlight and App Store submission pipeline for the Memori iOS app. Follow every step in order. Do NOT skip steps. Report progress to the user after each major phase.

## Step 1: Pre-flight Checks

1. Run `git status` to check if the working directory is clean. If there are uncommitted changes, **warn the user** and ask whether to proceed or commit first.
2. Run `git log --oneline -1` to show the latest commit (what's being shipped).
3. Read the current `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from `MindRestore.xcodeproj/project.pbxproj` to determine the current version and build number.
4. **Ask the user** for:
   - The new version number (suggest incrementing the patch version from the current one, e.g., 1.1.3 -> 1.1.4)
   - The new build number (suggest incrementing from the current one)
   - The "What's New" text for the App Store (en-US). Also ask if they want different text for es-MX or if Claude should translate the en-US text to Spanish.
5. **Wait for the user's response before proceeding.** Do not continue until the user confirms.

## Step 2: Bump Version

1. Use `sed` to update ALL occurrences of `MARKETING_VERSION` in `MindRestore.xcodeproj/project.pbxproj` to the new version number:
   ```bash
   sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = {NEW_VERSION};/g" MindRestore.xcodeproj/project.pbxproj
   ```
2. Use `sed` to update ALL occurrences of `CURRENT_PROJECT_VERSION` in `MindRestore.xcodeproj/project.pbxproj` to the new build number:
   ```bash
   sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = {NEW_BUILD};/g" MindRestore.xcodeproj/project.pbxproj
   ```
3. Verify the changes with `grep` to confirm the version was updated correctly.
4. Commit the version bump:
   ```bash
   git add MindRestore.xcodeproj/project.pbxproj
   git commit -m "Bump version to v{NEW_VERSION} build {NEW_BUILD}"
   ```

## Step 3: Archive

1. Clean previous build artifacts:
   ```bash
   rm -rf build/MindRestore.xcarchive build/export
   ```
2. Run the archive build (**this takes several minutes** — use a generous timeout of 600000ms):
   ```bash
   xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Release -destination 'generic/platform=iOS' -archivePath build/MindRestore.xcarchive archive -allowProvisioningUpdates
   ```
3. **Verify** the archive succeeded by checking:
   - The exit code is 0
   - The output contains `** ARCHIVE SUCCEEDED **`
   - The file `build/MindRestore.xcarchive` exists
4. If the archive fails, show the user the error output and stop. Do NOT proceed to upload.

## Step 4: Upload to App Store Connect

1. Create the ExportOptions.plist file:
   ```bash
   cat > /tmp/ExportOptions.plist << 'PLIST'
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>teamID</key>
       <string>73668242TN</string>
       <key>method</key>
       <string>app-store</string>
       <key>destination</key>
       <string>upload</string>
   </dict>
   </plist>
   PLIST
   ```
2. Run the export/upload (**this can take several minutes** — use a generous timeout of 600000ms):
   ```bash
   xcodebuild -exportArchive -archivePath build/MindRestore.xcarchive -exportPath build/export -exportOptionsPlist /tmp/ExportOptions.plist -allowProvisioningUpdates
   ```
3. **Verify** the upload succeeded by checking:
   - The exit code is 0
   - The output contains `** EXPORT SUCCEEDED **`
4. If the upload fails, show the user the error output and stop.
5. Tell the user: "Build uploaded to App Store Connect. It will take 5-15 minutes for Apple to process it."

## Step 5: App Store Connect API Setup

Use the App Store Connect REST API for all steps below. Generate a JWT for authentication.

### 5a: Generate JWT

Generate a JWT token using Python with PyJWT and ES256:

```bash
python3 -c "
import jwt, time

key_id = '9GRLL5VKUX'
issuer_id = 'ab66930d-a8da-451a-81e7-1cdd5f229aaf'

with open('/Users/dylanmiller/Downloads/AuthKey_9GRLL5VKUX.p8', 'r') as f:
    private_key = f.read()

now = int(time.time())
payload = {
    'iss': issuer_id,
    'iat': now,
    'exp': now + 1200,
    'aud': 'appstoreconnect-v1'
}

token = jwt.encode(payload, private_key, algorithm='ES256', headers={'kid': key_id})
print(token)
"
```

Store the token in a shell variable for subsequent API calls. **Regenerate the token if any API call returns 401.**

### 5b: Create or Find the App Store Version

1. Check if a version with the new version number already exists:
   ```bash
   curl -s -H "Authorization: Bearer $TOKEN" \
     "https://api.appstoreconnect.apple.com/v1/apps/6760178716/appStoreVersions?filter[platform]=IOS&filter[versionString]={NEW_VERSION}" | python3 -m json.tool
   ```
2. If the version does NOT exist, create it:
   ```bash
   curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     "https://api.appstoreconnect.apple.com/v1/appStoreVersions" \
     -d '{
       "data": {
         "type": "appStoreVersions",
         "attributes": {
           "platform": "IOS",
           "versionString": "{NEW_VERSION}"
         },
         "relationships": {
           "app": {
             "data": {
               "type": "apps",
               "id": "6760178716"
             }
           }
         }
       }
     }' | python3 -m json.tool
   ```
3. Save the version ID for later steps.

### 5c: Update "What's New" Text

For each locale (en-US and es-MX):

1. Get the localization ID:
   ```bash
   curl -s -H "Authorization: Bearer $TOKEN" \
     "https://api.appstoreconnect.apple.com/v1/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations" | python3 -m json.tool
   ```
2. Update (PATCH) the localization with the "What's New" text:
   ```bash
   curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     "https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}" \
     -d '{
       "data": {
         "type": "appStoreVersionLocalizations",
         "id": "{LOCALIZATION_ID}",
         "attributes": {
           "whatsNew": "{WHATS_NEW_TEXT}"
         }
       }
     }' | python3 -m json.tool
   ```
3. If a localization for es-MX doesn't exist, create it with a POST to `/v1/appStoreVersionLocalizations`.

### 5d: Wait for Build Processing

Poll App Store Connect every 30 seconds until the build appears and finishes processing:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.appstoreconnect.apple.com/v1/builds?filter[app]=6760178716&filter[version]={NEW_BUILD}&filter[processingState]=PROCESSING,VALID" | python3 -m json.tool
```

- If `processingState` is `PROCESSING`, wait 30 seconds and poll again.
- If `processingState` is `VALID`, the build is ready. Save the build ID.
- If no build is found after the first few polls, that's normal — it can take 5-15 minutes to appear. Keep polling.
- **Timeout after 20 minutes** of polling. If the build still hasn't appeared, tell the user to check App Store Connect manually and provide instructions for the remaining steps.
- Report progress to the user periodically (e.g., "Still waiting for build processing... (3 minutes elapsed)").

### 5e: Attach Build to Version

```bash
curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "https://api.appstoreconnect.apple.com/v1/appStoreVersions/{VERSION_ID}" \
  -d '{
    "data": {
      "type": "appStoreVersions",
      "id": "{VERSION_ID}",
      "relationships": {
        "build": {
          "data": {
            "type": "builds",
            "id": "{BUILD_ID}"
          }
        }
      }
    }
  }' | python3 -m json.tool
```

### 5f: Set Export Compliance

Set `usesNonExemptEncryption` to `false` on the build:

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "https://api.appstoreconnect.apple.com/v1/builds/{BUILD_ID}/relationships/buildBetaDetail" \
  -d '... '
```

Actually, use this endpoint to update the build's beta detail:

```bash
# First get the buildBetaDetail ID
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.appstoreconnect.apple.com/v1/builds/{BUILD_ID}/buildBetaDetail" | python3 -m json.tool

# Then patch it
curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "https://api.appstoreconnect.apple.com/v1/buildBetaDetails/{BETA_DETAIL_ID}" \
  -d '{
    "data": {
      "type": "buildBetaDetails",
      "id": "{BETA_DETAIL_ID}",
      "attributes": {
        "autoNotifyEnabled": true
      }
    }
  }' | python3 -m json.tool
```

For the App Store version's export compliance (not beta), use the `appStoreVersions` relationship or check if the build already has compliance set. If Apple prompts for compliance, update via:

```bash
curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "https://api.appstoreconnect.apple.com/v1/builds/{BUILD_ID}" \
  -d '{
    "data": {
      "type": "builds",
      "id": "{BUILD_ID}",
      "attributes": {
        "usesNonExemptEncryption": false
      }
    }
  }' | python3 -m json.tool
```

## Step 6: Submit for Review

1. Create a review submission:
   ```bash
   curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     "https://api.appstoreconnect.apple.com/v1/reviewSubmissions" \
     -d '{
       "data": {
         "type": "reviewSubmissions",
         "attributes": {
           "platform": "IOS"
         },
         "relationships": {
           "app": {
             "data": {
               "type": "apps",
               "id": "6760178716"
             }
           }
         }
       }
     }' | python3 -m json.tool
   ```
2. Add the version as a review submission item:
   ```bash
   curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     "https://api.appstoreconnect.apple.com/v1/reviewSubmissionItems" \
     -d '{
       "data": {
         "type": "reviewSubmissionItems",
         "relationships": {
           "reviewSubmission": {
             "data": {
               "type": "reviewSubmissions",
               "id": "{SUBMISSION_ID}"
             }
           },
           "appStoreVersion": {
             "data": {
               "type": "appStoreVersions",
               "id": "{VERSION_ID}"
             }
           }
         }
       }
     }' | python3 -m json.tool
   ```
3. Confirm/submit the review:
   ```bash
   curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     "https://api.appstoreconnect.apple.com/v1/reviewSubmissions/{SUBMISSION_ID}" \
     -d '{
       "data": {
         "type": "reviewSubmissions",
         "id": "{SUBMISSION_ID}",
         "attributes": {
           "submitted": true
         }
       }
     }' | python3 -m json.tool
   ```
4. Verify the submission state is `WAITING_FOR_REVIEW` or similar.

## Step 7: Post-Ship

1. Push the version bump commit to the remote:
   ```bash
   git push origin HEAD
   ```
2. Create a git tag for the release:
   ```bash
   git tag v{NEW_VERSION}-{NEW_BUILD}
   git push origin v{NEW_VERSION}-{NEW_BUILD}
   ```
3. Report the final status to the user:
   ```
   v{NEW_VERSION} build {NEW_BUILD} submitted for App Store review.

   - Version bump committed and pushed
   - Archive built and uploaded
   - What's New text updated (en-US + es-MX)
   - Build attached to version
   - Review submission created

   Track status at: https://appstoreconnect.apple.com/apps/6760178716/appstore
   ```

## Error Handling

- If ANY step fails, stop and report the error clearly to the user. Do not proceed to the next step.
- If the archive fails, it is often due to code signing. Show the full error.
- If the upload fails, check that the ExportOptions.plist is correct.
- If ASC API calls return 401, regenerate the JWT token and retry.
- If ASC API calls return 409 (conflict), the resource may already exist — check and adapt.
- If build processing times out, provide the user with manual instructions for the remaining steps (attach build, set compliance, submit for review) in App Store Connect.

## Important Notes

- TARGETED_DEVICE_FAMILY must remain `1` (iPhone only). Do NOT change this.
- `ScreenshotDataGenerator` must be wrapped in `#if DEBUG` or archive will fail.
- The `build/` directory is gitignored — do not try to commit anything in it.
- Always use timeout of 600000ms for archive and upload commands (they are slow).
- The P8 key file is at `/Users/dylanmiller/Downloads/AuthKey_9GRLL5VKUX.p8` — do not move or modify it.
