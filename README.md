# ReactPod

ReactPod is a React + Vite iPod Classic style music player.

## Web Development

1. Install dependencies:
   `npm install`
2. Start dev server:
   `npm run dev`
3. Build production bundle:
   `npm run build`

## iOS (Standalone App via Capacitor)

1. Install dependencies (includes Capacitor):
   `npm install`
2. Create iOS project (one-time):
   `npm run ios:add`
3. Sync latest web build into iOS project:
   `npm run ios:sync`
4. Open Xcode project:
   `npm run ios:open`
5. In Xcode, select your Apple Development Team and run on Simulator or device.

## iOS Import Behavior

- iOS does not support folder-picking in the same way desktop browsers do.
- ReactPod automatically falls back to file-based import on iOS.
- Select multiple audio files from the Files app to import music.
