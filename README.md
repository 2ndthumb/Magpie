<p align="center">
  <img src="assets/magpie.png" alt="Magpie Logo" width="200" height="200"/>
</p>

# Magpie

Magpie is a modern, open-source clipboard manager for macOS, designed to help you organize, search, and manage your clipboard history with ease.

## Features
- Menu bar app for quick access
- Rich clipboard history (text, images, links)
- Quick search and preview
- Drag-and-drop support
- Keyboard shortcuts
- Privacy-first: all data stored locally

## Installation

### Download
- Download the latest `.dmg` from the [Releases](https://github.com/2ndthumb/Magpie/releases) page.
- Open the DMG and drag **Magpie.app** to your **Applications** folder.

### Build from Source
1. Clone the repo:
   ```sh
   git clone git@github.com:2ndthumb/Magpie.git
   cd Magpie
   ```
2. Open `clipScope.xcodeproj` in Xcode.
3. Select the `Magpie` scheme and build (⌘B).
4. Run the app (⌘R) or create a DMG as described below.

## Creating a DMG
To create a distributable DMG:
```sh
xcodebuild -scheme Magpie -configuration Release
# Then run the provided script or use hdiutil as shown in the docs.
```

## Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License
[MIT](LICENSE) 