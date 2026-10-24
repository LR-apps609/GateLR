#!/usr/bin/env bash
# Giro di prova sull'emulatore: installa l'APK, apre ogni scheda, fa le foto e controlla che l'app non si chiuda.
set -u
OUT=${1:-shots}; mkdir -p "$OUT"
APK=$(ls android/app/build/outputs/apk/debug/*.apk | head -1)
adb install -r -g "$APK"
adb shell pm grant app.gatelr android.permission.ACCESS_FINE_LOCATION || true
adb shell pm grant app.gatelr android.permission.POST_NOTIFICATIONS || true
adb emu geo fix 11.2558 43.7696 || true          # Firenze, Settore A
adb logcat -c
adb shell am start -W -n app.gatelr/.MainActivity
sleep 8

shot() { adb exec-out screencap -p > "$OUT/$1.png"; echo "foto $1"; }
# Tocca il centro dell'elemento con quel testo (dal dump di uiautomator)
tap() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  local b; b=$(adb shell cat /sdcard/ui.xml | tr '>' '\n' | grep -F "text=\"$1\"" | head -1 | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | grep -oE '[0-9]+' | tr '\n' ' ')
  if [ -z "$b" ]; then echo "non trovo «$1»"; return 1; fi
  set -- $b; adb shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 )); sleep 4
}

shot 01-varco
tap "Map" && sleep 8 && shot 02-mappa
tap "Trip" && shot 03-viaggio
adb shell input text "Palazzo%sVecchio"; sleep 8; shot 04-ricerca
adb shell input keyevent 111
tap "Garage" && shot 05-garage
tap "Account" && shot 06-account
tap "Gate" && adb shell input swipe 500 1800 500 600 && sleep 2 && shot 07-varco-zone

adb logcat -d > "$OUT/logcat.txt"
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt"; then
  echo "::error::L'app si è chiusa"; grep -A30 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -60; exit 1
fi
echo "Giro completato"
