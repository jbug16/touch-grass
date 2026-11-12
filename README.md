# touch-grass

A lightweight macOS menu bar app that reminds you to touch grass.

The menu bar shows a tree and the minutes until the next break during today’s shift. After the shift ends, the countdown goes away. Breaks follow the weekly schedule: every 15 minutes from the start of that day’s shift, a 15-second break. Every fourth break is 5 minutes. A break never starts at or after the shift ends. Monday–Friday 9:00–17:00 is the default. Sleep and wake recompute the next break from the clock.

## Build and run

```bash
./scripts/test.sh
./scripts/build-app.sh
open "build/Touch Grass.app"
```

`open "build/Touch Grass.app" --args --preview-break` shows a 15-second break after a few seconds.

The test script runs `swift test` with Swift Testing. The command-line tools ship that framework and not XCTest.

Open Schedule from the menu to change each weekday. Launch at Login uses the app’s bundle, so move `Touch Grass.app` into `/Applications` before turning that on. macOS may also ask you to allow it under System Settings → General → Login Items.

Xcode is optional. The Swift package builds with the command-line tools into a signed menu-bar app (`LSUIElement`, so it stays out of the Dock).
