# NeverMiss

A native macOS menu bar application that connects to multiple Google Calendar accounts and displays upcoming meeting information with popup notifications.

## Features

- **Menu Bar Display**: Shows your next meeting name and time until it starts directly in the menu bar
- **Multiple Accounts**: Connect multiple Google Calendar accounts
- **Click to Join**: One-click join for Zoom, Google Meet, Microsoft Teams, and Webex meetings
- **Popup Notifications**: Modal popup window appears before meetings start (configurable timing)
- **Accepted-Only Filter**: Option to only show meetings you've accepted
- **Automatic Refresh**: Calendar data refreshes every 5 minutes (configurable)
- **Auto Re-authentication**: Prompts to re-authenticate when Google tokens expire

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)
- A Google Cloud project with Calendar API enabled

## Google Cloud Setup

Before using NeverMiss, you need to create Google Cloud credentials:

### Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" at the top, then "New Project"
3. Name it "NeverMiss" (or any name you prefer)
4. Click "Create"

### Step 2: Enable the Google Calendar API

1. In your new project, go to "APIs & Services" > "Library"
2. Search for "Google Calendar API"
3. Click on it and press "Enable"

### Step 3: Configure OAuth Consent Screen

1. Go to "APIs & Services" > "OAuth consent screen"
2. Select "External" and click "Create"
3. Fill in the required fields:
   - **App name**: NeverMiss
   - **User support email**: Your email
   - **Developer contact email**: Your email
4. Click "Save and Continue"
5. On the "Scopes" page, click "Add or Remove Scopes"
6. Add these scopes:
   - `https://www.googleapis.com/auth/calendar.readonly`
   - `https://www.googleapis.com/auth/calendar.events.readonly`
   - `https://www.googleapis.com/auth/userinfo.email`
   - `https://www.googleapis.com/auth/userinfo.profile`
7. Click "Save and Continue"
8. On "Test users", click "Add Users" and add your Google email address
9. Click "Save and Continue"

### Step 4: Create OAuth Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. Select "iOS" as the application type (this works for macOS)
4. Enter:
   - **Name**: NeverMiss macOS
   - **Bundle ID**: `com.nevermiss.app`
5. Click "Create"
6. **Copy the Client ID** (it looks like `xxx.apps.googleusercontent.com`)

### Step 5: Configure the App

1. Copy the template configuration file:
   ```bash
   cp NeverMiss/Sources/Config.template.swift NeverMiss/Sources/Config.swift
   ```
2. Edit `NeverMiss/Sources/Config.swift` and replace the placeholders with your credentials:

```swift
static let googleClientID = "123456789-abcdefg.apps.googleusercontent.com"
static let googleClientSecret = "GOCSPX-your-client-secret"  // or empty string for iOS credentials
```

> **Note**: `Config.swift` is gitignored to prevent accidentally committing your credentials. Only `Config.template.swift` is tracked in git.

## Building the App

### Using Xcode

1. Open `NeverMiss.xcodeproj` in Xcode
2. Select your development team in the project settings (Signing & Capabilities)
3. Build and run (⌘R)

### Using Command Line

```bash
xcodebuild -project NeverMiss.xcodeproj -scheme NeverMiss -configuration Release build
```

## Mac App Store Distribution

This section documents how to set up automated App Store distribution via GitHub Actions.

### Prerequisites

- Apple Developer Program membership ($99/year)
- App Store Connect access
- GitHub repository with Actions enabled

### Step 1: Register an App ID

1. Go to [Apple Developer Portal](https://developer.apple.com/account) → Certificates, Identifiers & Profiles
2. Click **Identifiers** → **+** button
3. Select **App IDs** → Continue
4. Select **App** → Continue
5. Enter:
   - **Description**: NeverMiss
   - **Bundle ID**: Explicit → `page.conx.nevermiss` (or your chosen bundle ID)
6. Enable **App Sandbox** under Capabilities
7. Click **Continue** → **Register**

### Step 2: Create Certificates

You need two certificates for App Store distribution:

#### Mac App Distribution Certificate
1. On your Mac, open **Keychain Access**
2. Go to **Keychain Access** → **Certificate Assistant** → **Request a Certificate From a Certificate Authority**
3. Enter your email, leave CA Email blank, select **Saved to disk**
4. Save the `.certSigningRequest` file
5. In Apple Developer Portal → **Certificates** → **+**
6. Select **Mac App Distribution** → Continue
7. Upload your CSR file → Continue → Download
8. Double-click the `.cer` file to install in Keychain

#### Mac Installer Distribution Certificate
1. Repeat the same process, but select **Mac Installer Distribution** instead

#### Export Certificates for GitHub Actions
1. In Keychain Access, find **3rd Party Mac Developer Application: [Your Name]**
2. Right-click → **Export** → Save as `.p12` with a strong password
3. Repeat for **3rd Party Mac Developer Installer: [Your Name]**
4. Base64 encode both:
   ```bash
   base64 -i application.p12 | pbcopy  # Copy to clipboard
   base64 -i installer.p12 | pbcopy
   ```

### Step 3: Create Provisioning Profile

1. Apple Developer Portal → **Profiles** → **+**
2. Select **Mac App Store Connect** → Continue
3. Select your App ID → Continue
4. Select your **Mac App Distribution** certificate → Continue
5. Name it (e.g., "NeverMiss App Store") → Generate → Download
6. Base64 encode it:
   ```bash
   base64 -i NeverMiss_App_Store.provisionprofile | pbcopy
   ```

### Step 4: Create App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → Users and Access → Integrations → App Store Connect API
2. Click **+** to generate a new key
3. Name: "GitHub Actions", Access: **App Manager**
4. Download the `.p8` file (you can only download once!)
5. Note the **Key ID** shown in the table
6. Note the **Issuer ID** at the top of the page (UUID format)
7. Base64 encode the key:
   ```bash
   base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
   ```

### Step 5: Create App in App Store Connect

1. App Store Connect → Apps → **+** → **New App**
2. Select **macOS** platform
3. Enter:
   - **Name**: Your app's display name (must be unique on App Store)
   - **Primary Language**: English (or your preference)
   - **Bundle ID**: Select your registered App ID
   - **SKU**: A unique identifier (e.g., `nevermiss`)
4. Click **Create**

### Step 6: Configure GitHub Secrets

Add these secrets to your repository (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `APPSTORE_CERTIFICATE_BASE64` | Base64-encoded Mac App Distribution `.p12` |
| `APPSTORE_CERTIFICATE_PASSWORD` | Password for the distribution certificate |
| `APPSTORE_INSTALLER_CERTIFICATE_BASE64` | Base64-encoded Mac Installer Distribution `.p12` |
| `APPSTORE_INSTALLER_CERTIFICATE_PASSWORD` | Password for the installer certificate |
| `APPSTORE_PROVISIONING_PROFILE_BASE64` | Base64-encoded provisioning profile |
| `APPSTORE_API_KEY_ID` | App Store Connect API Key ID |
| `APPSTORE_API_ISSUER_ID` | App Store Connect Issuer ID (UUID) |
| `APPSTORE_API_KEY_BASE64` | Base64-encoded `.p8` API key file |
| `GOOGLE_CLIENT_ID` | Your Google OAuth Client ID |

### Step 7: Run the Workflow

1. Go to Actions → **App Store Release**
2. Click **Run workflow**
3. Enter the version number (e.g., `1.0.1`)
4. Click **Run workflow**

The workflow will:
- Build the app with App Sandbox entitlements
- Sign it with your Mac App Distribution certificate
- Create a signed `.pkg` installer
- Upload to App Store Connect

### Step 8: Submit for Review

1. In App Store Connect, go to your app
2. Wait for the build to finish processing (5-30 minutes)
3. Select the build under the macOS section
4. Fill in required metadata (screenshots, description, etc.)
5. Submit for App Review

### Info.plist Requirements

The following keys are required for App Store submission:

```xml
<key>LSApplicationCategoryType</key>
<string>public.app-category.productivity</string>
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### Troubleshooting

#### "No suitable application records were found"
The app doesn't exist in App Store Connect. Create it first (Step 5).

#### "Bundle version must be higher than previously uploaded"
You've already uploaded this version. Increment the version number.

#### Authentication errors (401)
- Ensure you're using a **Team Key** (not Individual Key) from App Store Connect
- Verify the Key ID and Issuer ID are correct
- Check the `.p8` file was base64 encoded correctly

## Usage

1. **Launch the app** - It will appear as an icon in your menu bar
2. **Add an account** - Click the menu bar item and select "Add Account"
3. **Sign in with Google** - A browser window will open for authentication
4. **View meetings** - Your upcoming meetings will appear in the dropdown
5. **Join meetings** - Click the "Join" button next to any meeting with a video link
6. **Configure settings** - Access Settings to customize notification timing and filters

## Settings

Access settings through the menu bar dropdown or by pressing ⌘, when the app is focused.

- **Refresh interval**: How often to fetch new calendar data (1, 5, or 15 minutes)
- **Notification lead time**: When to show popup notifications (1-15 minutes before)
- **Show popup notifications**: Enable/disable popup windows
- **Play sound**: Play a sound when popup appears
- **Only show accepted meetings**: Filter to show only meetings you've accepted
- **Launch at login**: Start NeverMiss automatically when you log in

## Troubleshooting

### "Access blocked" during sign-in
Your Google Cloud project is in "Testing" mode. Make sure you added your email as a test user in the OAuth consent screen settings.

### Calendar not syncing
1. Check that the account is enabled in Settings > Accounts
2. Try removing and re-adding the account
3. Ensure you have an internet connection

### Popup not appearing
1. Check that "Show popup notifications" is enabled in Settings
2. Verify the notification lead time setting
3. Make sure the meeting has a future start time

## Privacy

NeverMiss:
- Only reads your calendar data (never modifies it)
- Stores authentication tokens locally in app preferences
- Never sends your data anywhere except to Google's APIs
- Runs entirely on your local machine

## License

PostgreSQL License - feel free to modify and distribute as needed.
