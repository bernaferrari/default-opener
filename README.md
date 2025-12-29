# Default Opener

<p align="center">
  <img src="assets/header.png" alt="Default Opener" width="100%">
</p>

<p align="center">
  <b>Take back control of your default apps on macOS</b>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#cli-usage">CLI Usage</a> •
  <a href="#backup--restore">Backup & Restore</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/badge/license-Apache%202.0-blue" alt="Apache 2.0 License">
</p>

---

**Default Opener** is a powerful macOS utility that lets you view and manage which applications open your files and URL schemes. Stop apps from hijacking your file associations without permission.

## Screenshots

| Main Screen | Dark Mode |
|:-:|:-:|
| ![Main Screen](assets/main-screen.png?raw=true) | ![Dark Mode](assets/dark-mode.png?raw=true) |

| URL Schemes | Change All From App |
|:-:|:-:|
| ![URL Schemes](assets/url-schemes.png?raw=true) | ![Change All From App](assets/change-all-from-app.png?raw=true) |

## Why Default Opener?

Ever installed an app that suddenly became the default for all your code files? Or wanted VS Code to open `.json` files instead of Xcode? Default Opener solves these frustrations:

- **See what's happening**: View all file type associations at a glance
- **Bulk operations**: Select multiple file types and change them all at once
- **Filter by app**: See all files handled by a specific app and reassign them
- **Backup & restore**: Save your preferences and restore them after system updates or new app installations
- **Instant undo**: Changed something by mistake? Undo immediately via toast notification

## Features

### File Type Management
- View default apps for 100+ common file extensions
- See all available apps that can handle each file type
- One-click to change the default handler
- Right-click context menu for quick actions (Copy Extension, Copy UTI, Change Default)
- Support for documents, code, images, video, audio, and archives

### URL Scheme Management
- Manage `http://`, `https://`, `mailto:`, `ssh://`, and more
- Change your default browser, email client, or other handlers
- Right-click context menu for quick actions

### Bulk Operations
- Filter file types by category (Code, Documents, Images, etc.)
- Filter by current handler app
- Select multiple file types and change them all at once
- "Replace all" - change every file type from one app to another
- Smart app picker with Registered Handlers, Popular Editors, and All Apps sections

### Backup & Restore
- Create timestamped backups of all your associations
- Import backups from any location (Dropbox, iCloud, USB drive, etc.)
- Reveal backups in Finder for easy sharing
- Preview changes before restoring
- JSON format for easy inspection and sharing

### Instant Undo
- Toast notification appears after every change
- **Undo button** right in the toast - click within 4 seconds to revert
- Works for single changes and bulk operations

### External Change Detection
- **Automatically detects** when other apps hijack your file associations
- Alert on launch when changes are found
- See exactly which apps changed which file types
- **Revert all changes** or keep them as the new baseline
- Never be surprised by VS Code or Xcode taking over your files again

### Automatic Updates
- Built-in Sparkle framework for seamless updates
- Automatic update checks in the background
- Manual check available via menu bar

## Requirements

- **macOS 13.0** (Ventura) or later
- **Xcode 15+** (for building from source)

## Installation

### Download

Download the latest release from the [Releases](https://github.com/bernaferrari/default-opener/releases) page:
- **Default Opener.app** - GUI application (move to `/Applications`)
- **default-opener** - CLI tool (move to `/usr/local/bin`)

> **Note:** On first launch, right-click the app and select "Open" to bypass Gatekeeper.

### Build from Source

```bash
git clone https://github.com/bernaferrari/default-opener
cd default-opener

# Build CLI
swift build -c release
# Binary is at .build/release/opener

# Build GUI (requires Xcode)
xcodebuild -project DefaultOpener/DefaultOpener.xcodeproj -scheme DefaultOpener -configuration Release
# App is in build/Release/
```

## CLI Usage

### View Commands

```bash
# List all file type associations
opener list extensions

# List URL scheme associations
opener list schemes

# Filter by category
opener list ext --category code
opener list ext --category documents
opener list ext --category images

# Get info about a specific extension
opener get .json
opener get .json --all  # Show all available handlers

# Get info about a URL scheme
opener get https
opener get mailto --all
```

### Set Commands

```bash
# Set default app by bundle ID
opener set .json com.microsoft.VSCode
opener set .py com.apple.dt.Xcode

# Set default browser
opener set https com.apple.Safari

# Set default email client
opener set mailto com.apple.mail
```

### Backup & Restore

```bash
# Create a backup
opener backup
opener backup --output ~/Desktop/my-prefs.json

# List backups
opener backups
opener backups --path  # Show backup directory

# Preview a restore
opener restore latest --dry-run

# Restore from backup
opener restore latest
opener restore ~/Desktop/my-prefs.json
```

### Find Apps

```bash
# List installed apps with bundle IDs
opener apps

# Search for an app
opener apps Safari
opener apps Code
```

## GUI App

The Default Opener app provides a beautiful native macOS interface for managing your file associations.

### Main Features

- **Sidebar navigation**: Browse by category or by app
- **Search**: Quickly find any file type or app (searches names and bundle IDs)
- **Bulk selection**: Use selection mode to pick multiple items
- **One-click change**: Click any file type to see available apps
- **Right-click menu**: Copy extension, UTI, or change default quickly
- **App view**: See all file types handled by a specific app
- **Smart app discovery**: Popular editors like VS Code, Sublime, Cursor, and Zed shown first

### Backups in the GUI

- **Create Backup**: One-click to save your current associations
- **Import**: Restore from any backup file on your system
- **Reveal in Finder**: Quickly access backup files to share or move them
- **Restore**: Apply a previous backup with confirmation dialog

### Settings

Access via **Default Opener > Settings** or `Cmd+,`:
- View current version and build number
- Check for updates manually

### Tips

- Use the search bar to quickly find file types (also searches bundle IDs like "microsoft")
- Click on an app in the sidebar to see all files it handles
- Use "Change All" to reassign all files from one app to another
- Right-click any row to copy information or change the default
- Create a backup before installing new apps

## Supported File Types

### Code & Text
`.json` `.xml` `.yaml` `.yml` `.toml` `.md` `.markdown` `.py` `.js` `.ts` `.jsx` `.tsx` `.html` `.css` `.scss` `.swift` `.kt` `.java` `.go` `.rs` `.c` `.cpp` `.cs` `.rb` `.php` `.sh` `.sql` `.lua` `.vue` `.svelte` `.astro` `.graphql` and many more...

### Documents
`.txt` `.rtf` `.pdf` `.doc` `.docx` `.xls` `.xlsx` `.ppt` `.pptx` `.pages` `.numbers` `.key` `.csv`

### Images
`.png` `.jpg` `.jpeg` `.gif` `.webp` `.svg` `.ico` `.bmp` `.tiff` `.heic` `.psd` `.ai` `.sketch` `.fig`

### Video
`.mp4` `.mov` `.avi` `.mkv` `.webm` `.flv` `.wmv`

### Audio
`.mp3` `.m4a` `.aac` `.wav` `.flac` `.ogg` `.aiff`

### Archives
`.zip` `.tar` `.gz` `.7z` `.rar` `.dmg` `.iso`

## Supported URL Schemes

| Scheme | Description |
|--------|-------------|
| `http://` `https://` | Web browsers |
| `mailto:` | Email clients |
| `ssh://` | SSH clients |
| `tel:` `sms:` | Phone & Messages |
| `facetime:` | FaceTime |
| `vscode://` `cursor://` `zed://` | Code editors |
| `slack://` `discord://` `zoom://` | Communication apps |

## How It Works

Default Opener uses macOS's Launch Services framework to read and modify file type associations. The same APIs that the system uses when you right-click a file and select "Open With" → "Other..." → "Always Open With".

Key APIs used:
- `LSCopyDefaultRoleHandlerForContentType` - Get current default
- `LSCopyAllRoleHandlersForContentType` - List available handlers
- `LSSetDefaultRoleHandlerForContentType` - Set new default
- `UTType` - Convert file extensions to Uniform Type Identifiers

## Privacy & Security

- **No network access**: Works entirely offline (except for optional update checks)
- **No telemetry**: No data is collected or transmitted
- **Open source**: Review the code yourself
- **Non-sandboxed**: Required to access Launch Services APIs (cannot be distributed on Mac App Store)

## Troubleshooting

### Changes not taking effect?

macOS caches file associations. Try:
1. Quit and reopen Finder
2. Log out and back in
3. Rebuild the Launch Services database (nuclear option):
   ```bash
   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
   ```

### App not showing as option?

The app may not have registered itself for that file type. Try:
1. Opening the app once
2. Running `opener list extensions` to refresh

### Permission denied?

Make sure you're running the CLI tool or app with your user account, not as root.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.

## Credits

Inspired by:
- [SwiftDefaultApps](https://github.com/Lord-Kamina/SwiftDefaultApps)
- [duti](https://github.com/moretension/duti)

---

<p align="center">
  Made with care for the macOS community
</p>
