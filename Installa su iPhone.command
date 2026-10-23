#!/bin/zsh
# ════════════════════════════════════════════════════════════════════
#  Prepara GateLR per il tuo iPhone e apre Xcode.
#  Fai doppio clic su questo file. Poi in Xcode: scegli il tuo Apple ID
#  (Signing & Capabilities → Team), scegli l'iPhone in alto e premi ▶︎.
# ════════════════════════════════════════════════════════════════════
cd "${0:A:h}" || exit 1
clear
print ""
print "  GateLR — preparo il progetto per l'iPhone"
print "  ══════════════════════════════════════════"
print ""

fail() { print ""; print "  ❌ $1"; print ""; print "  Mandami uno screenshot di questa finestra."; exit 1 }

# 1. Xcode
print "  1/3  Controllo Xcode…"
[[ -d /Applications/Xcode.app ]] || fail "Non trovo Xcode in Applicazioni. Installalo dal Mac App Store e aprilo una volta."
if [[ $(xcode-select -p 2>/dev/null) != /Applications/Xcode.app/* ]]; then
  print "       Imposto Xcode come strumento predefinito (ti chiede la password del Mac)…"
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer || fail "Non riesco a impostare Xcode."
fi
xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1 || sudo xcodebuild -runFirstLaunch >/dev/null 2>&1
print "       ✅"

# 2. XcodeGen (crea il progetto dal file project.yml)
print "  2/3  Controllo XcodeGen…"
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen || fail "Non riesco a installare XcodeGen con Homebrew."
  else
    fail "Manca XcodeGen. Installa Homebrew da https://brew.sh e riprova."
  fi
fi
xcodegen generate --quiet || fail "Non riesco a creare il progetto."
print "       ✅"

# 3. Apri Xcode
print "  3/3  Apro Xcode…"
open GateLR.xcodeproj
print ""
print "  In Xcode:"
print "   • a sinistra clicca «GateLR» (l'icona blu), poi il target GateLR"
print "   • scheda «Signing & Capabilities» → Team: scegli il tuo Apple ID"
print "     (se non c'è: Xcode → Settings → Accounts → +)"
print "   • in alto scegli il tuo iPhone collegato con il cavo"
print "   • premi ▶︎"
print ""
print "  La prima volta, sull'iPhone:"
print "   • Impostazioni → Privacy e sicurezza → Modalità sviluppatore → attiva"
print "   • Impostazioni → Generali → VPN e gestione dispositivi → fidati del tuo Apple ID"
print ""
