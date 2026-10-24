#!/usr/bin/env bash
# Giro di prova sull'emulatore: installa l'APK, apre ogni scheda, fa le foto e controlla che l'app non si chiuda.
set -u
OUT=${1:-shots}; mkdir -p "$OUT"
APK=$(ls android/app/build/outputs/apk/release/*.apk 2>/dev/null | head -1)
[ -n "$APK" ] || APK=$(ls android/app/build/outputs/apk/debug/*.apk | head -1)
echo "::notice::Provo $APK"
adb wait-for-device; until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 2; done; sleep 20
adb install -r -g "$APK"
adb shell pm grant app.gatelr android.permission.ACCESS_FINE_LOCATION || true
adb shell pm grant app.gatelr android.permission.POST_NOTIFICATIONS || true
adb emu geo fix 11.2558 43.7696 || true          # Firenze, Settore A
adb logcat -c
adb shell am start -W -n app.gatelr/.MainActivity
sleep 8

shot() { dismiss; adb exec-out screencap -p > "$OUT/$1.png"; echo "::notice::foto $1"; }
# Tocca il centro dell'elemento con quel testo (dal dump di uiautomator)
find() {
  # uiautomator a volte non legge lo schermo (animazioni in corso): fino a 4 tentativi
  local r="" i
  for i in $(seq 1 ${TRIES:-4}); do
    adb shell rm -f /sdcard/ui.xml; adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    r=$(adb shell cat /sdcard/ui.xml 2>/dev/null | tr '>' '\n' | grep -F "text=\"$1\"" | sed -n "${2:-1}p" | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | grep -oE '[0-9]+' | tr '\n' ' ')
    [ -n "$r" ] && break; sleep 2
  done
  echo "$r"
}
# Gli avvisi «… isn't responding» dell'emulatore (launcher, sistema): si chiudono con «Wait»
dismiss() { local w; [ -n "$(TRIES=1 find "GateLR isn't responding")" ] && echo "::error::GateLR non risponde (ANR)"; w=$(TRIES=1 find "Wait"); [ -n "$w" ] && { set -- $w; adb shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 )); sleep 2; }; }
tap() {
  local b; b=$(find "$1" "${2:-1}")
  if [ -z "$b" ]; then dismiss; b=$(find "$1" "${2:-1}"); fi
  if [ -z "$b" ]; then echo "::warning::non trovo «$1»"; return 1; fi
  set -- $b; adb shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 )); sleep 4
}

shot 00-benvenuto
tap "Continue"; sleep 4
shot 01-varco
tap "Map" && sleep 8 && shot 02-mappa
tap "Trip" && shot 03-viaggio
adb shell input text "Palazzo%sVecchio"; sleep 8; shot 04-ricerca
adb shell input keyevent 4; sleep 2
tap "Palazzo Vecchio" 2 && sleep 3 && shot 04b-risposta
adb shell input swipe 500 1800 500 500 && sleep 2 && shot 04c-risposta-sotto
adb emu geo fix 11.2486 43.7765 || true          # Stazione di Santa Maria Novella, fuori dal Settore A
sleep 12
tap "Check the drive" && sleep 8 && shot 04d-tragitto
tap "Garage" && shot 05-garage
tap "Account" && shot 06-account
adb shell input swipe 500 1800 500 900; sleep 2
tap "Read the sign ›" && sleep 2 && tap "e.g. 7.30-20.00 feriali" && adb shell input text "7.30-20.00%sferiali" && sleep 2 && adb shell input keyevent 4 && sleep 1 && shot 06b-cartello
adb shell input keyevent 4; sleep 2
tap "Got a fine? ›" && sleep 2 && shot 06c-multa
adb shell input keyevent 4; sleep 2
tap "Map" && sleep 6 && adb shell input tap 540 1200 && sleep 3 && shot 02b-mappa-zona
adb shell input keyevent 4; sleep 2
tap "Gate" && adb shell input swipe 500 1800 500 600 && sleep 2 && shot 07-varco-zone

# In italiano e al buio: lingua dell'app (Android 13+) e tema scuro
adb shell cmd uimode night yes; adb shell cmd locale set-app-locales app.gatelr --locales it-IT; sleep 3
adb shell am force-stop app.gatelr; adb shell am start -W -n app.gatelr/.MainActivity; sleep 8
shot 08-it-scuro-varco
tap "Viaggio" && shot 09-it-scuro-viaggio
tap "Mappa" && sleep 6 && shot 10-it-scuro-mappa
tap "Account" && shot 11-it-scuro-account

adb logcat -d > "$OUT/logcat.txt"
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt"; then
  echo "::error::L'app si è chiusa"; grep -A30 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -60; exit 1
fi
echo "Giro completato"
