# Building and installing Hudyat

How to build the Android app and put it on a phone.

## What you need

| Tool | Version | Used for |
|---|---|---|
| Flutter | 3.47 (Dart 3.13.1 or later) | The app |
| Android SDK | Platform tools with `adb` | Building and installing |
| JDK | 21 | `maplibre_gl` needs it |
| Bun and `pmtiles` | Any recent | Cutting the offline map |
| An Android phone | Android 11 (API 30) or later | The on-device model runtime needs API 30 |

The JDK path is set in `android/gradle.properties`. It points at the
Homebrew location on an Apple-silicon Mac; change that line to your own
JDK 21, or delete it if JDK 21 is your default.

## 1. Get the code and packages

```sh
git clone https://github.com/ianlabicani/hudyat.git
cd hudyat
flutter pub get
```

## 2. Get the offline map

The data pack is in the repository. The map (about 53 MB) is not, so cut
it once before the first build. This step needs internet.

```sh
cd pack
bun run map
cd ..
```

To rebuild the data pack from its sources as well, see
[From sources to the pack](PACK.md).

## 3. Build

```sh
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. It
is signed with the debug key, so it installs over a debug copy.

## 4. Install on the phone

Turn on Developer options and USB debugging, connect the phone, and
install:

```sh
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**Do not uninstall first.** Uninstalling or clearing the app's storage
deletes the models folder, and the models are 0.5 to 1 GB to copy again.

## 5. Copy the models (first install only)

The app works without the models: the rules, keyword search, hotlines
and the map do not need them. The models add understanding of typed
messages, the wording check and the optional AI notes.

**On the phone:** Setup in the app shows each missing model with an
**Open model page** button, the file names and the folder to put them in.

**From a computer:** accept the Gemma terms on Hugging Face
([EmbeddingGemma](https://huggingface.co/litert-community/embeddinggemma-300m),
[Gemma 3 1B](https://huggingface.co/litert-community/Gemma3-1B-IT)),
download the three files, open Hudyat once, then push them:

```sh
adb shell mkdir -p /sdcard/Android/data/com.example.hudyat/files/models
adb push embeddinggemma-300M_seq256_mixed-precision.tflite /sdcard/Android/data/com.example.hudyat/files/models/
adb push sentencepiece.model /sdcard/Android/data/com.example.hudyat/files/models/
adb push Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm /sdcard/Android/data/com.example.hudyat/files/models/
```

Then open **Setup** in the app and tap **Check again**.

## 6. Set up on the phone

1. Open Hudyat. Home says **Ready offline** once Setup is happy.
2. For automatic checking, open **Automatic checking**, turn it on and
   allow the SMS permissions and notifications.
3. If Android will not show the SMS permission prompt, open Settings,
   then Apps, then Hudyat, tap the menu at the top right and choose
   **Allow restricted settings**. Android requires this for apps
   installed outside the Play Store.
4. To add the widget, long-press the home screen, choose Widgets and
   pick Hudyat.

## 7. Check it works

Turn on airplane mode and follow
[Try it in two minutes](../README.md#try-it-in-two-minutes).

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| Gradle fails with a Java version error | Gradle is not using JDK 21. Fix the path in `android/gradle.properties`. |
| The Map screen shows no map | The map file was missing when the app was built. Run step 2 and build again. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | The installed copy has a different signature. Back up the models folder, uninstall, install, and copy the models back. |
| Setup says a model is missing | The file name must match exactly, in the folder Setup shows. Tap "Check again" after copying. |
| The widget picker shows the old design | The launcher caches the preview. It refreshes after the phone or launcher restarts. |
| The build seems stale after pulling changes | Run `flutter clean`, then `flutter pub get` and build again. Do not uninstall. |
| You want the app to download the models itself | Build with `--dart-define=HUGGINGFACE_TOKEN=your-token`. Never commit or share that build. |

## Tests

```sh
flutter analyze
flutter test
cd pack && bun test
cd ../android && ./gradlew :app:testDebugUnitTest
```

These prove the code's behaviour on the laptop. The models, GPS, the
offline map, tap-to-call and automatic checking still need checking on
the phone.

A debug build (`flutter build apk --debug`) runs the recovery check for
texts every 2 minutes instead of about every 12 hours, which is useful
for watching it work.
