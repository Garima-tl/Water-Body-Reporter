# Water Body Reporter 🌍📍

A Flutter application for reporting and monitoring water bodies with geolocation capabilities. Users can submit reports with photos, descriptions, and locations, which are displayed on an interactive map.

## Key Features
- 📸 Capture photos using camera or gallery
- 🗺 Interactive map with current location
- 📍 Save reports with GPS coordinates
- 📋 View report history with images
- 🔄 Real-time updates using Hive local storage
- 📱 Cross-platform support (Android, iOS, Web)

## Prerequisites
- Flutter SDK (version 3.0.0 or higher)
- Android Studio/VSCode with Flutter extension
- Physical device or emulator
- Web browser (Chrome recommended for web testing)

## Installation
1. Clone the repository:
```bash
git clone https://github.com/yourusername/water-body-reporter.git
```
2.Navigate to project directory:
```bash
cd water-body-reporter
```
3.Install dependencies:
```bash
flutter pub get
```
4.Running the app
```bash
flutter run
```
## Usage

### 1. Submit a Report:
- Click the floating action button (**+**)
- Choose **camera** or **gallery** for photos
- Add **title** and **description**
- Submit to **save with current location**

### 2. View Reports:
- Tap **map markers** to see details
- Click **list icon (📋)** to view all reports
- Click **location icon (🎯)** to recenter map

### 3. Map Controls:
- **Pinch** to zoom
- **Drag** to pan
- **Double-tap** to zoom in
