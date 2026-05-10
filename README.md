# momento

a digital place for your trinkets, knick-knacks, and keepsakes :D

Point your camera at something, tap it, and Momento lifts it out of the
background using on-device Vision. No backend, no AI API costs.

## Requirements
- Xcode 15+
- iPhone running iOS 17+ (Subject Lifting needs real hardware)
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## First run
```bash
xcodegen generate
open Momento.xcodeproj
```
In Xcode: target `Momento` → Signing & Capabilities → pick your team.
Plug in an iPhone, hit Run.

## Status
- ✅ Phase 1: scaffold
- ✅ Phase 2: live camera (AVFoundation)
- ✅ Phase 3: tap-to-lift (`VNGenerateForegroundInstanceMaskRequest`)
- ⏭ Phase 4: SwiftData persistence wired; gallery UI next
