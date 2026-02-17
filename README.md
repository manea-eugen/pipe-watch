# PipeWatch

A native macOS menu bar app that watches your GitLab pipelines and notifies you when they complete. No browser tab refreshing, no polling dashboards -- just push your code and get a notification when it's done.

> This project was built entirely with AI assistance.


## Features

- **Lives in the menu bar** -- no Dock icon, no windows, always accessible
- **Automatic polling** -- watches your GitLab pipelines every 30 seconds (configurable)
- **Smart filtering** -- only shows pipelines *you* triggered, not the entire project
- **Native macOS notifications** -- alerts on pipeline success, failure, cancellation, or manual step
- **Manual action detection** -- detects when GitLab marks a pipeline as "success" but manual jobs are pending
- **Current step display** -- shows the active job/stage for running pipelines
- **Failed job details** -- shows the failed job name and retry count
- **Open in browser** -- click a notification or a pipeline row to jump straight to GitLab
- **Secure token storage** -- your GitLab PAT is stored in the macOS Keychain, not in plaintext
- **Status-aware menu bar icon** -- icon changes color based on the worst active pipeline status (red = failed, blue = running, orange = pending, purple = manual, green = passed)

## Requirements

- macOS 14+ (Sonoma)
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A GitLab Personal Access Token with `read_api` scope

## Getting Started

```bash
# Clone the repo
git clone https://github.com/manea-eugen/pipe-watch.git
cd pipe-watch

# Build and run
./build.sh Debug --run
```

The app will appear in your menu bar. Click the icon, open **Settings** (gear icon), and enter:

1. Your GitLab instance URL (e.g. `https://gitlab.com`)
2. Your Personal Access Token
3. Click **Save & Reconnect**

Your pipelines will start appearing within seconds.

## How It Works

The app follows a simple poll-and-diff architecture:

```
┌─────────────────┐
│ PipelineMonitor  │──── timer (every 30s) ────┐
└─────────────────┘                             │
                                                ▼
                                      ┌──────────────────┐
                                      │  GitLabService    │
                                      │  (actor, async)   │
                                      └──────────────────┘
                                                │
                          ┌─────────────────────┼─────────────────────┐
                          ▼                     ▼                     ▼
                   GET /api/v4/user    GET /projects?       GET /projects/{id}/
                   (who am I?)         membership=true      pipelines?username=me
                                       (active projects)    (my pipelines)
                          │                     │                     │
                          └─────────────────────┼─────────────────────┘
                                                ▼
                                      ┌──────────────────┐
                                      │  State Diffing    │
                                      │  (old vs new)     │
                                      └──────────────────┘
                                                │
                                    pipeline status changed?
                                    (e.g. running → success)
                                                │
                                                ▼
                                      ┌──────────────────┐
                                      │ macOS Notification │
                                      │ via UNUserNotif.  │
                                      └──────────────────┘
```

### Step by step

1. **`PipelineMonitor`** fires on a timer (default 30 seconds, minimum 10 seconds).
2. **`GitLabService`** (a Swift actor for thread safety) makes several sets of API calls:
   - `GET /api/v4/user` -- identifies the current user (cached after the first call)
   - `GET /api/v4/projects?membership=true&last_activity_after=24h_ago` -- finds recently active projects (paginated)
   - `GET /api/v4/projects/{id}/pipelines?username={you}&updated_after=24h_ago` -- fetches your pipelines per project, concurrently
   - `GET /api/v4/projects/{id}/pipelines/{pid}/jobs` -- fetches jobs per pipeline to detect running step, failures, and manual actions
3. **State diffing** -- the monitor compares each pipeline's current status against its previously known status. If a pipeline transitioned to a terminal state (`success`, `failed`, `canceled`) or requires manual action, it triggers a notification.
4. **`NotificationManager`** delivers a native macOS notification with the project name, pipeline ID, and branch. Clicking the notification opens the pipeline in your browser.

### Why polling instead of webhooks?

This is a local desktop app with no server component. GitLab webhooks require an HTTP endpoint to receive events, which would mean running a local server and configuring each project. Polling the API every 30 seconds is simple, reliable, and stays well within GitLab's rate limits.

## Project Structure

```
PipeWatch/
├── project.yml                   # XcodeGen project spec
├── build.sh                      # Build & run script
├── Info.plist                    # LSUIElement=true (no Dock icon)
├── PipeWatch.entitlements        # Network + Keychain permissions
├── Assets.xcassets/              # App icon assets
│
└── PipeWatch/                    # Source code
    ├── PipeWatchApp.swift        # @main entry, MenuBarExtra + AppDelegate
    │
    ├── Models/
    │   ├── Pipeline.swift        # Pipeline, PipelineStatus, TrackedPipeline, PipelineJob
    │   └── GitLabProject.swift   # GitLabProject, GitLabUser
    │
    ├── Services/
    │   ├── GitLabService.swift          # REST API client (actor, URLSession)
    │   ├── PipelineMonitor.swift        # Timer-based poller + state diffing
    │   └── NotificationManager.swift    # macOS notification delivery + actions
    │
    ├── Stores/
    │   └── AppState.swift               # @Observable central state, UserDefaults persistence
    │
    ├── Views/
    │   ├── PipelineListView.swift       # Main popover: flat pipeline list sorted by created date
    │   ├── PipelineRowView.swift        # Single pipeline row (status, branch, step, duration)
    │   └── SettingsView.swift           # Token, URL, interval, notification toggles
    │
    └── Utilities/
        └── KeychainHelper.swift         # Keychain read/write/delete for the PAT
```

## Configuration

All settings are accessible from the **Settings** panel (click the gear icon in the popover footer):

| Setting | Description | Default |
|---------|-------------|---------|
| GitLab Instance URL | Base URL of your GitLab instance | `https://gitlab.com` |
| Personal Access Token | Your PAT (stored in Keychain) | -- |
| Polling Interval | How often to check for updates (10-120s) | 30s |
| Notify on success | Send a notification when a pipeline passes | On |
| Notify on failure | Send a notification when a pipeline fails | On |

Settings are persisted in `UserDefaults`. The token is stored securely in the macOS Keychain.

## GitLab Token Setup

1. Go to your GitLab instance → **Settings** → **Access Tokens** (or visit `https://gitlab.com/-/user_settings/personal_access_tokens`)
2. Click **Add new token**
3. Give it a name (e.g. "PipeWatch")
4. Select the **`read_api`** scope -- this is the only scope needed
5. Set an expiration date
6. Click **Create personal access token** and copy the token
7. Paste it into the app's Settings panel

## Build Script

The `build.sh` script handles project generation and compilation:

```bash
# Build in Debug mode
./build.sh

# Build in Release mode
./build.sh Release

# Build and launch immediately
./build.sh Debug --run
```

The script runs `xcodegen generate` first, then `xcodebuild`. The compiled `.app` ends up in Xcode's DerivedData directory.

## Contributing

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Run `./build.sh` to verify it compiles
5. Open a pull request

## License

Unlicense (public domain) -- see [LICENSE](LICENSE). Do whatever you want with it.
