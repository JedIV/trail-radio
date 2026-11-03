# Trail Radio

A little pocket prairie: a native, offline iPhone and iPad ambience app with a green monochrome interface.

Warm, bass-rich wind, soft hoofbeats, wagon creaks, and distant birds are synthesized on-device. Each layer has its own volume control. Playback continues with the screen locked; an optional sleep timer stops it later. No accounts, ads, subscriptions, analytics, or tracking.

## Build

Open `TrailRadio.xcodeproj` in Xcode, choose your development team in Signing & Capabilities, select an iPhone or simulator, and Run. Requires iOS/iPadOS 17 or later. For a physical device, enable Developer Mode and trust your developer signature when prompted.

The checked-in project contains the development team used for this prototype. Choose your own team and unique bundle identifier when building your own copy.

```sh
./test-audio.sh
xcodebuild -project TrailRadio.xcodeproj -scheme TrailRadio -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The audio checks render every layer at 44.1 and 48 kHz, verify finite output and clipping headroom, and check reproducibility. Real-device testing is also necessary: simulators do not enforce every audio-session restriction.

## Use

Tap **Take the Trail** to play and **Rest a While** to pause. Adjust the four layers independently. The app remembers your volume settings. With the sleep timer off, sound continues until paused. Headphone disconnection pauses playback; phone calls and other interruptions follow iOS audio-session behavior.

All sounds are generated locally; playback works without internet reception. The synthesis is adapted from the ambience we made for our Brooklyn Trail emulator, rather than using recordings or game assets.

## Privacy and support

- [Support](https://jediv.github.io/trail-radio/)
- [Privacy policy](https://jediv.github.io/trail-radio/privacy.html)
- Contact: john.e.dougherty@gmail.com

Settings stay on your device. The app has no network requests during playback and requests no microphone, location, contacts, or health permissions. See `TrailRadio/PrivacyInfo.xcprivacy` for its required-reason API declaration.

## Release status

Version 1.0/build 2 is being prepared for App Store submission. It has not been uploaded or approved. Listing drafts and remaining submission work are in [release/README.md](release/README.md). The support website source is in `docs/`.

The sound generator has been checked at both common sample rates, and playback has been confirmed on a physical iPhone after fixing an invalid audio-session option. Extended screen-locked playback, timer expiry, and interruption behavior still need release testing on a physical device.

Use a comfortable listening level. Trail Radio is an ambience app and does not provide medical treatment.
