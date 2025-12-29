# Default Opener

<p align="center">
  <img src="assets/header.png" alt="Default Opener" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/badge/license-Apache%202.0-blue" alt="Apache 2.0 License">
</p>

A macOS utility to view and manage default applications for file types and URL schemes.

| Main Screen | Dark Mode |
|:-:|:-:|
| ![Main Screen](assets/main-screen.png?raw=true) | ![Dark Mode](assets/dark-mode.png?raw=true) |

| URL Schemes | Change All From App |
|:-:|:-:|
| ![URL Schemes](assets/url-schemes.png?raw=true) | ![Change All From App](assets/change-all-from-app.png?raw=true) |

## Features

- View and change default apps for 100+ file extensions
- Manage URL scheme handlers (http, mailto, ssh, etc.)
- Bulk operations - change multiple file types at once
- Backup and restore your preferences
- Instant undo via toast notification
- Detect when apps hijack your file associations

## Installation

Download from [Releases](https://github.com/bernaferrari/default-opener/releases) or build from source:

```bash
git clone https://github.com/bernaferrari/default-opener
cd default-opener
xcodebuild -project DefaultOpener/DefaultOpener.xcodeproj -scheme DefaultOpener -configuration Release
```

## Requirements

- macOS 13.0+

## License

Apache License 2.0
