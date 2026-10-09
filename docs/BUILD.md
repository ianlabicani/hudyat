# Building and installing Hudyat

How to build the Android app and put it on a phone, from a clean checkout
or over a copy that is already installed.

## What you need

| Tool | Version | Used for |
|---|---|---|
| Flutter | 3.47 (Dart 3.13.1 or later) | The app |
| Android SDK | Platform tools with `adb` | Building and installing |
| JDK | 21 | `maplibre_gl` needs it |
| Bun | Any recent | Rebuilding the data pack and the map |
| `pmtiles` | Any recent | Cutting the offline map |
| An Android phone | Android 11 (API 30) or later | The on-device model runtime needs API 30 |

The JDK path is set in `android/gradle.properties`:

```
org.gradle.java.home=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
```

That is where `brew install openjdk@21` puts it on an Apple-silicon Mac.
On another machine, change that line to your own JDK 21, or delete it if
JDK 21 is already your default.

## 1. Get the code and packages

```sh
git clone https://github.com/ianlabicani/hudyat.git
cd hudyat
flutter pub get
```

## 2. Get the offline map

The data pack (`assets/pack/metro-manila.sqlite`) is in the repository.
The map (`assets/pack/metro-manila.pmtiles`, about 53 MB) is not, so cut
it once before the first build. This step needs internet.

```sh
cd pack
bun run map
cd ..
```

The app builds without the map file, but the Map screen then has no
map to show, so cut it before building.

To rebuild the data pack from its sources as well (optional):

```sh
cd pack
bun run fetch    # downloads into pack/raw/, reused on later runs
bun run build    # writes assets/pack/metro-manila.sqlite
cd ..
```

## 3. Build

```sh
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

Use the debug build for a demo: its recovery check for texts runs every
2 minutes instead of about every 12 hours. `flutter build apk` (release)
also works and is signed with the debug key in this project.

## 4. Install on the phone

Turn on Developer options and USB debugging on the phone, connect it,
and confirm it is listed:

```sh
adb devices
```

Install over whatever is already there. The `-r` flag keeps the app's
data, which is where the models and the flagged messages live:

```sh
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Or build, install and start in one step, with logs and hot reload:

```sh
flutter run
```

**Do not uninstall first.** `adb uninstall`, `flutter install`,
`flutter run --uninstall-first`, `adb shell pm clear` and "Clear storage"
all delete the models folder, and the models are 0.5 to 1 GB to copy
again. If an install fails with a signature mismatch, the copy on the
phone was signed on another machine: back up the models folder first
(step 5 shows where it is), then uninstall and install.

## 5. Copy the models (first install only)

The app works without the models: the rules, keyword search, hotlines
and the map do not need them. The models add understanding of typed
messages, the wording check and the optional AI notes.

Setup in the app walks through this on the phone itself: each missing
model has an **Open model page** button, the file names, and the folder
with a **Copy folder path** button. Download the files in the phone's
browser and move them with its file manager.

From a computer, accept the Gemma terms on Hugging Face
([EmbeddingGemma](https://huggingface.co/litert-community/embeddinggemma-300m),
[Gemma 3 1B](https://huggingface.co/litert-community/Gemma3-1B-IT)),
download these three files, and push them to the app's folder:

```sh
adb shell mkdir -p /sdcard/Android/data/com.example.hudyat/files/models
adb push embeddinggemma-300M_seq256_mixed-precision.tflite /sdcard/Android/data/com.example.hudyat/files/models/
adb push sentencepiece.model /sdcard/Android/data/com.example.hudyat/files/models/
adb push Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm /sdcard/Android/data/com.example.hudyat/files/models/
```

Open Hudyat once before pushing so the folder belongs to the app. Then
open **Setup** in the app and tap **Check again**. Setup shows the exact
folder it reads.

A build can instead download the models itself on first run:

```sh
flutter build apk --debug --dart-define=HUGGINGFACE_TOKEN=your-token
```

Never commit or share a build that contains a private token.

## 6. Set up on the phone

1. Open Hudyat. Home should say **Ready offline** once Setup is happy.
2. For automatic checking, open **Automatic checking**, turn it on and
   allow the SMS permissions and notifications.
3. If Android will not show the SMS permission prompt, open the phone's
   Settings, then Apps, then Hudyat, tap the menu at the top right and
   choose **Allow restricted settings**. Then allow SMS under
   Permissions. Android does this for apps installed outside the Play
   Store.
4. To add the widget, long-press the home screen, choose Widgets and
   pick Hudyat.

## 7. Check it works

With airplane mode on:

1. Type "Binabaha na dito, hanggang tuhod na, may matanda kami" on Home.
   A strip reading "Understood: Flood rescue" should appear (models
   needed), or tap the Flood rescue button.
2. Pick a city. The card shows that city's hotlines with Call buttons.
3. Tap a place to open the offline map.
4. Open **Check a message**, paste a suspicious text and tap Check.

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| Gradle fails with a Java version error | Gradle is not using JDK 21. Fix the path in `android/gradle.properties`. |
| The Map screen shows no map | `metro-manila.pmtiles` was not in `assets/pack/` when the app was built. Run step 2 and build again. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | The installed copy has a different signature. Back up the models folder, uninstall, install, and copy the models back. |
| The widget picker shows the old widget design | The launcher caches the preview. It refreshes after the new build is installed and the phone or launcher restarts. A widget already on the home screen updates at the next check, or when Hudyat is opened. |
| Setup says a model is missing | The file name must match exactly, in the folder Setup shows. Tap "Check again" after copying. |
| The build seems stale after pulling changes | Run `flutter clean`, then `flutter pub get` and build again. Do not combine this with an uninstall. |

## Tests

```sh
flutter analyze
flutter test
cd pack && bun test
cd ../android && ./gradlew :app:testDebugUnitTest
```

These prove the code's behaviour on the laptop. The models, GPS, the
offline map, tap-to-call and automatic checking still need to be checked
on the phone.
