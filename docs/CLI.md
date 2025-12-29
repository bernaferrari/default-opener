# CLI Usage

## Installation

```bash
swift build -c release
cp .build/release/opener /usr/local/bin/
```

## Commands

### List

```bash
opener list extensions              # All file types
opener list schemes                 # All URL schemes
opener list ext --category code     # Filter by category
```

### Get

```bash
opener get .json                    # Current handler
opener get .json --all              # All available handlers
opener get https
```

### Set

```bash
opener set .json com.microsoft.VSCode
opener set https com.apple.Safari
opener set mailto com.apple.mail
```

### Backup & Restore

```bash
opener backup                       # Create backup
opener backup --output ~/prefs.json
opener backups                      # List backups
opener restore latest
opener restore ~/prefs.json
```

### Find Apps

```bash
opener apps                         # List all with bundle IDs
opener apps Safari                  # Search
```
