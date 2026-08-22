# Déjà Entendu — pipeline setup

This folder now has both your original Xcode-created shell and the full
import + transcription pipeline, wired together via `project.yml`
(XcodeGen). Nothing has touched your `.xcodeproj` file directly — it gets
regenerated from `project.yml` instead.

## What changed in this folder

- Added: `project.yml`, everything under `App/` (except your old
  `ContentView.swift` / `Item.swift`, which are untouched but no longer
  part of the build), and everything under `ShareExtension/` (a new target).
- Untouched: your original `Déjà Entendu/`, `Déjà EntenduTests/`,
  `Déjà EntenduUITests/` folders and their stock template files — they're
  just not referenced by the new `project.yml`, so they won't compile in.
  Delete them whenever you like, or leave them; either is harmless.
- Naming: app display name "Déjà Entendu", bundle ID
  `com.ncubeeight.dejaentendu`, extension `com.ncubeeight.dejaentendu.share`,
  App Group `group.com.ncubeeight.dejaentendu` — consistent across every
  entitlements file and Swift constant that needs it.

## What you still need to do, in Terminal on your Mac

```
brew install xcodegen        # one-time, skip if already installed
cd ~/Documents/"Déjà Entendu"
xcodegen generate
open "Déjà Entendu.xcodeproj"
```

Then in Xcode:

1. Signing & Capabilities → pick your Team for **both** targets
   (`Déjà Entendu` and `AddToDejaEntendu`). Your existing project didn't
   have a team selected yet, so this is a required manual step — with
   Automatic Signing on, Xcode will register the App ID and App Group in
   your developer account the first time it needs to.
2. Before your first TestFlight upload, create the app record once at
   appstoreconnect.apple.com → My Apps → **+** → New App, using
   `com.ncubeeight.dejaentendu` as the bundle ID.
3. Set the run destination to **Any iOS Device (arm64)**, then
   **Product → Archive**.
4. In Organizer: select the archive → **Distribute App** → **App Store
   Connect** → **Upload** → Automatically manage signing → Upload.

## One more thing worth doing first

Your git repo here has an empty "Initial Commit" — none of the actual
project files are tracked yet (`git status --short` shows everything as
untracked). Worth committing before you generate/build, e.g.:

```
git add -A
git commit -m "Add Déjà Entendu pipeline (import + Taiwanese Mandarin transcription)"
```

## Reminder on frameworks used

`SpeechAnalyzer`/`SpeechTranscriber` (transcription, locale set to
`zh-Hant-TW`) and `FoundationModels` (on-device study notes) both require
iOS 26+; `FoundationModels` additionally needs an Apple Intelligence–eligible
device with the feature enabled in Settings — `StudyNoteGenerator.swift`
checks `SystemLanguageModel.default.availability` and surfaces a message
rather than crashing when it's unavailable.
