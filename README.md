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
