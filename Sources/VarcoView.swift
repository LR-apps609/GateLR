import SwiftUI
import MapKit
import UIKit

/// «Varco»: la prima pagina di GateLR 2.0, una sola domanda: «Posso entrare?». Sul blu notte dell'identità:
/// in cima una striscia di mappa viva (Mapbox 3D al crepuscolo, o la mappa di Apple se Mapbox non c'è) che porta alla
/// scheda Mappa sulla zona della risposta; poi l'ora e il veicolo («Adesso ▾», l'auto), la ricerca e la risposta detta
/// come sul pannello del varco («Non entrare.», «Arrivo sereno.»…), con il pannello vero che gira quando cambia.
/// Il posto è quello cercato (anche in Mappa); senza, la posizione se sei dentro una ZTL.
struct VarcoView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: AppRouter
    @ObservedObject private var monitor = GateMonitor.shared
    // 1.19.5: il guardiano non si osserva qui (pubblica la distanza a ogni posizione e ridisegnava tutta la pagina,
    // striscia di Mapbox compresa): lo osserva solo il suo riquadro, GuardianBannerSlot
    @StateObject private var search = AddressSearch()
    @Binding var showZone: Bool
    @Binding var tab: Tab
    @FocusState private var typing: Bool
    @State private var resolving = false
    @State private var mapFailed = !NotteMap.hasToken
    /// 1.19.5: Mapbox pronto (stile e zone): fino ad allora sopra la striscia c'è lo scheletro, non un rettangolo vuoto
    @State private var mapReady = false
    @State private var parkSheet = false
    /// 2.2: il posto del foglio «Parcheggia fuori», fermato al tocco (la zona davanti cambia mentre ti muovi)
    @State private var parkPlace: Place?
    @State private var driving = false
    /// 1.20.2: «Usa la mia posizione» toccato prima del permesso: la posizione si usa appena arriva
    @State private var wantsLocation = false
    /// 2.0 (B27): «Usa la mia posizione» con la posizione approssimativa: si chiede di cercare l'indirizzo
    @State private var approximateNote = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let moment = store.moment(ctx.date)
            // 2.2: il posto cercato; senza, dove sei o la zona davanti entro 300 m (Adesso)
            let subject = Adesso.subject(store: store, place: store.place, location: monitor.answerLocation, at: moment)
            let check = subject?.check
            let answer = check.map { Home2Answer($0, now: ctx.date) }
            Group {
                if regular {
                    // 2.3 iPad (tavola I-iPad): la mappa e la risposta affiancate; la risposta in una colonna leggibile
                    HStack(alignment: .top, spacing: 16) {
                        if !Misure.noStrip {
                            mapStrip(check: check, mood: answer?.mood ?? cityMood(at: moment), at: moment, tall: true)
                                .padding(.vertical, 12)
                        }
                        ScrollView {
                            column(check: check, answer: answer, subject: subject, moment: moment, now: ctx.date)
                                .padding(.top, 6).padding(.bottom, 24)
                        }
                        .frame(width: 440)
                    }
                    .padding(.horizontal, 16)
                } else {
                    ScrollView {
                        column(check: check, answer: answer, subject: subject, moment: moment, now: ctx.date)
                            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 24)
                            .readableFrame()
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .background(sceneBackground(answer?.mood).ignoresSafeArea())
        }
        // 2.3 (direzione C): Giorno e Notte automatici, dal telefono (prima sempre blu notte)
        .onAppear { search.focus(on: store.city) }
        .onChange(of: store.cityId) { search.focus(on: store.city) }
        .onChange(of: monitor.location != nil) { _, has in if has && wantsLocation { useMyLocation() } }
        .sheet(isPresented: $parkSheet) { parkOutsideSheet }
        .fullScreenCover(isPresented: $driving) { DriveView() }
        // 2.2 (funzione 33): la richiesta di recensione non è più qui, dopo la prima risposta: arriva dopo un viaggio
        // salvato (TripView), mai in mezzo a un momento di stress
    }

    /// iPad e finestre larghe: mappa e risposta affiancate
    private var regular: Bool { sizeClass == .regular }

    /// La colonna della pagina: testata, contesto, ricerca e risposta
    private func column(check: PlaceCheck?, answer: Home2Answer?, subject: Adesso.Subject?, moment: Date, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !Misure.noStrip && !regular { mapStrip(check: check, mood: answer?.mood ?? cityMood(at: moment), at: moment) }
            ContextChips(material: true)
            GuardianBannerSlot()
            searchField
            if approximateNote && store.place == nil {
                Label(L("Approximate location: search the address instead."), systemImage: "location.slash")
                    .font(.app(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("varco.approximate")
            }
            if typing && !search.query.isEmpty {
                suggestions
            } else {
                if let check, let answer {
                    answerCard(check, answer, ahead: subject?.aheadMeters)
                } else {
                    emptyCard
                }
                inCarButton
                nearYou(at: moment)
                if let next = store.trips.filter({ $0.arrival > now }).min(by: { $0.arrival < $1.arrival }) { tripRow(next) }
                StatusBanner(status: store.city.status, unofficial: store.city.hasUnofficialZones)
                Text("Road signs on site always win over the app.")
                    .font(.app(size: 12)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.snappy, value: store.place)
    }

    // MARK: Il posto della risposta

    /// Senza un posto: il colore della RispostaFinale della zona scelta (2.1, B26: prima rosso se attiva, verde se no,
    /// anche con dati non sicuri o da fonte non ufficiale)
    private func cityMood(at date: Date) -> Home2Answer.Mood {
        let f = RispostaFinale.of(store.answer(at: date, zone: store.zone, hotelInside: false), zone: store.zone, status: store.city.status)
        return Home2Answer.Mood(f.color)
    }

    /// 2.3: il fondo del tema, senza la luce colorata del pannello (S-Movimento: niente effetti decorativi)
    private func sceneBackground(_ mood: Home2Answer.Mood?) -> some View { Theme.ground }

    private var header: some View {
        HStack(spacing: 10) {
            Wordmark(size: 20)
            Spacer()
            Menu {
                ForEach(store.cities) { c in
                    Button(c.localizedName) { store.chooseCity(c.id) }
                }
            } label: {
                Label(store.city.localizedName, systemImage: "building.2")
                    .font(.app(size: 13, weight: .semibold)).lineLimit(1)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(Theme.ink)
            }
            .accessibilityLabel(String(format: L("City: %@"), store.city.localizedName))
            // 2.2: la fotocamera del cartello e l'icona del veicolo (Garage e Impostazioni), in ogni scheda
            TopActions(material: true, size: 36)
        }
    }

    // MARK: La striscia di mappa

    /// Il segno sul posto della striscia: lo spillo con il nome del posto cercato, il cartello della ZTL con il nome
    /// corto della zona senza un posto; niente quando il posto è la tua posizione (c'è già il pallino blu)
    static func stripMarker(check: PlaceCheck?, zone: Zone) -> StripMarkerKind? {
        guard let check else { return .zone(zone.shortName) }
        if check.place.name == L("My position") { return nil }
        return .destination(check.place.name)
    }

    /// La città dal vivo intorno al posto: un tocco apre la scheda Mappa sulla zona della risposta
    private func mapStrip(check: PlaceCheck?, mood: Home2Answer.Mood, at moment: Date, tall: Bool = false) -> some View {
        // Senza un posto cercato: la zona scelta, al centro della zona, con il suo cartello (non il centro della città)
        let zoneCenter = store.zone.region(padding: 1).center
        let place = check?.place ?? Place(name: store.zone.shortName, address: "",
                                          location: Coordinate(lat: zoneCenter.latitude, lon: zoneCenter.longitude))
        // Ogni zona con il colore della SUA risposta (lo Scudo Verde verde per un'auto ammessa, anche se l'hotel è nel Settore A rosso)
        // (colore della risposta per il tuo veicolo e righe se attiva, come sulla Mappa: MapTheme; le vie come corridoi)
        let rings = Dictionary(grouping: (check?.hits.first?.city ?? store.city).zones) {
            AccessCache.look($0, store: store, at: moment)
        }.mapValues { $0.map { ZoneShapes.shape(id: $0.id, perimeter: $0.perimeter)?.corridorCoords ?? $0.perimeter.map(\.cl) } }
        let marker = Self.stripMarker(check: check, zone: store.zone)
        // La tua posizione: c'è solo con il permesso. Il pallino blu, e la ripresa con te dentro se sei a meno di 5 km
        let user = monitor.location.map { Coordinate(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
        let height: CGFloat = tall ? 600 : check == nil ? 168 : 112
        let framing = StripFrame.make(target: place.location, user: user)
        return ZStack(alignment: .bottomLeading) {
            Group {
                if mapFailed {
                    VarcoAppleStrip(place: place, focus: check?.zone ?? (check == nil ? store.zone : nil),
                                    zones: rings, tint: mood.color, marker: marker, framing: framing, showsUser: user != nil,
                                    dark: scheme == .dark)
                } else {
                    Home2Map(place: place, zones: rings, mood: mood, mapMode: false, reduceMotion: reduceMotion, night: scheme == .dark,
                             ornamentBottom: 6, focusBottom: 0, marker: marker, user: user, stripPoints: height,
                             onFail: { mapFailed = true }, onReady: { mapReady = true })
                        // Mapbox può metterci qualche secondo (fino a 5 prima della mappa di Apple, MapboxFallback): la striscia neutra,
                        // senza il colore della risposta, finché lo stile non è caricato
                        .overlay { if !mapReady { MapStripSkeleton() } }
                }
            }
            .accessibilityHidden(true)
            LinearGradient(colors: [.clear, Color.black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)
            // Il tocco su tutta la striscia tranne il fondo, dove stanno logo e attribuzione di Mapbox
            Button { openMap(check) } label: {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 30)
            .accessibilityLabel(L("See the map"))
            // Quello che la striscia mostra: il cartello o la destinazione, e la tua posizione se è nella ripresa
            .accessibilityValue([marker?.accessibilityText, framing.includesUser ? L("Your position") : nil]
                .compactMap { $0 }.joined(separator: ", "))
            .accessibilityIdentifier("varco.mapstrip")
            if check?.unofficial == true {
                UnofficialBanner(compact: true)
                    .padding(8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }
            Label(L("See the map"), systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.app(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).frame(height: 26)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.leading, 10).padding(.bottom, 34)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        // Più bassa quando c'è una risposta: la risposta e i suoi pulsanti stanno nello schermo
        .frame(height: tall ? nil : height)
        .frame(maxHeight: tall ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    /// La scheda Mappa sulla zona della risposta (la mappa va sul posto scelto o sulla zona scelta, vedi MapScreen.focus)
    private func openMap(_ check: PlaceCheck?) {
        if let hit = check?.hit { store.cityId = hit.city.id; store.zoneId = hit.zone.id }
        tab = .map
    }

    // MARK: Ricerca

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.app(size: 17, weight: .semibold)).foregroundStyle(Theme.muted)
            TextField("", text: $search.query,
                      prompt: Text(L("Hotel, address or square")).foregroundColor(Theme.muted))
                .focused($typing)
                .submitLabel(.search)
                // 1.20.2: Invio sceglie il primo suggerimento (o lo aspetta, o riprova la ricerca)
                .onSubmit { search.submit() }
                .onReceive(search.picks) { choose($0) }
                .autocorrectionDisabled()
                .foregroundStyle(Theme.ink)
                .accessibilityLabel(L("Hotel, address or square"))
                .accessibilityIdentifier("varco.search")
            if resolving { ProgressView() }
            if !search.query.isEmpty {
                Button { search.clear(); typing = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                }
                .accessibilityLabel(L("Clear"))
            } else if monitor.location != nil || monitor.canAskLocation || monitor.locationDenied {
                // 1.20.2: c'è anche senza permesso: il primo tocco è il momento in cui iOS chiede la posizione.
                // 2.0 (B68): con la posizione negata resta, e porta alle Impostazioni di iOS
                Button { useMyLocation() } label: {
                    Image(systemName: monitor.locationDenied ? "location.slash" : "location.fill").foregroundStyle(Theme.ink)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                    .accessibilityLabel(L("Use my location"))
                    .accessibilityIdentifier("varco.locate")
            }
        }
        .font(.app(size: 17))
        .padding(.horizontal, 14).frame(minHeight: 52)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(typing ? Theme.ink : Theme.line, lineWidth: typing ? 2 : 1))
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 2.0 (B132): l'errore anche con i suggerimenti già in vista (il tocco su un suggerimento senza rete)
            if search.failed {
                SearchFailedRow(dark: false) { search.retry() }
            } else if search.results.isEmpty {
                Text(L("Keep typing…")).font(.app(size: 14)).foregroundStyle(Theme.muted).padding(14)
            }
            ForEach(Array(search.results.enumerated()), id: \.offset) { i, r in
                Button { choose(r) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill").font(.app(size: 22)).foregroundStyle(Theme.muted)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title).font(.app(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                            if !r.subtitle.isEmpty {
                                Text(r.subtitle).font(.app(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("varco.result.\(i)")
                if i < search.results.count - 1 { Divider().overlay(Theme.line).padding(.leading, 48) }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func choose(_ r: MKLocalSearchCompletion) {
        Task {
            resolving = true
            if let place = await search.resolve(r) {
                withAnimation(.snappy) { store.select(place) }
                search.query = ""
                typing = false
            }
            resolving = false
        }
    }

    private func useMyLocation() {
        // 1.20.2: senza permesso si chiede adesso (non più all'apertura dell'app); la risposta arriva con la posizione
        guard let here = monitor.location else { wantsLocation = true; monitor.askLocation(store: store); return }
        // 2.0 (B27): approssimativa → la richiesta di precisione temporanea; se resta approssimativa, si cerca l'indirizzo
        guard monitor.answerLocation != nil else {
            Task {
                await monitor.askPrecise()
                if monitor.answerLocation == nil { approximateNote = true; typing = true }
            }
            return
        }
        approximateNote = false
        wantsLocation = false
        store.select(Place(name: L("My position"), address: "",
                           location: Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude)))
    }

    // MARK: La risposta

    private func answerCard(_ check: PlaceCheck, _ a: Home2Answer, ahead: Double?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            placeRow(check, ahead: ahead)
            if a.unofficial { UnofficialBanner(source: a.unofficialSource) }
            // 2.3 (tavole S-Risposta, I-No, I-Si): il blocco pieno della risposta, forma + parola + colore, identico di
            // giorno e di notte. VoiceOver lo legge in un colpo solo, per primo («varco.answer», un solo elemento)
            RispostaBlock(stato: a.stato, title: a.headline, line: InCarView.zoneLine(check), detail: a.detail,
                          spokenExtra: spokenFor, identifier: "varco.answer")
                .id(a.headline)
                // S-Movimento: solo una dissolvenza di 200 ms quando la risposta cambia
                .transition(.opacity)
            actions(check)
            // Il pannello come lo vedrai al varco: sotto la risposta, più piccolo, luce neutra (non la contraddice mai)
            if a.showsPanel { GateLEDPanel(text: a.ledText, caption: a.ledCaption) }
            if let label = a.timeLabel {
                timeBlock(label, a)
            }
            // Città e zona sono già nel blocco: qui resta solo l'ora scelta
            if store.when != nil {
                Text(verbatim: String(format: L("For %@"), TimeChoice.label(store.when)))
                    .font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            // «Segnala un errore» per la zona della risposta
            if let hit = check.hit {
                ReportErrorButton(zone: hit.zone, city: hit.city)
                    .accessibilityIdentifier("varco.report")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 1.20.2: un identificatore solo della scheda della risposta (il giro delle foto aspetta questa, non la ricerca)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("varco.answerCard")
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: a.headline)
    }

    /// Detto da VoiceOver alla fine della risposta: «Per Golf diesel Euro 5, adesso»
    private var spokenFor: String {
        String(format: L("For %@"), store.vehicle.chipLabel) + ", " + TimeChoice.label(store.when).lowercased()
    }

    private func timeBlock(_ label: String, _ a: Home2Answer) -> some View {
        VStack(alignment: .leading, spacing: -4) {
            Text(label.uppercased()).font(Self.font(13, .bold)).kerning(1.4).foregroundStyle(Theme.muted)
            if let time = a.time {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: time)
                        .font(Self.font(56, .black)).monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                    if let day = a.day {
                        Text(verbatim: day).font(Self.font(18, .semibold)).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Il posto, con i recenti e gli hotel dei viaggi a un tocco, e la croce per tornare alla domanda
    private func placeRow(_ check: PlaceCheck, ahead: Double?) -> some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(Self.savedHotels(store.trips)) { p in
                    Button { store.select(p) } label: { Label(p.name, systemImage: "suitcase.rolling.fill") }
                }
                ForEach(store.recent.prefix(5)) { p in Button(p.name) { store.select(p) } }
            } label: {
                // 1.17.3: il posto è il titolo della scheda (grande, nel carattere dei titoli, fino a due righe), sotto
                // la città e la zona: si capisce subito di quale hotel parla la risposta. Il ▾ apre gli altri posti
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: Self.placeTitle(check))
                            .font(Self.font(30, .black)).foregroundStyle(Theme.ink)
                            .lineLimit(2).minimumScaleFactor(0.75)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.down").font(.app(size: 14, weight: .bold))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: placeSubtitle(check, ahead: ahead))
                        .font(.app(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(Self.placeTitle(check)), \(placeSubtitle(check, ahead: ahead))")
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("varco.place")
            Spacer(minLength: 4)
            if store.place != nil {
                Button { withAnimation(.snappy) { store.place = nil } } label: {
                    Image(systemName: "xmark").font(.app(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 32).background(Theme.raised, in: Circle())
                        .frame(width: Theme.Target.minimum, height: Theme.Target.minimum).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Clear"))
                .accessibilityIdentifier("varco.clear")
            }
        }
    }

    /// Il titolo della scheda: il nome del posto; la tua posizione si dice «La tua posizione»
    static func placeTitle(_ check: PlaceCheck) -> String {
        check.place.name == L("My position") ? L("Your position") : check.place.name
    }

    /// La riga sotto il titolo: città e zona che decide («Firenze · Scudo Verde»), l'area pedonale o «Fuori dalla ZTL»;
    /// fuori copertura nessuna città (la più vicina può essere a 30 km) e «Non conosciamo le ZTL di questo posto»
    /// 2.2: per la zona davanti, prima «120 m davanti a te»
    private func placeSubtitle(_ check: PlaceCheck, ahead: Double?) -> String {
        let city = check.city ?? (check.covered ? store.nearestCity(to: check.place.location) : nil)
        let where_ = check.pedestrian?.name ?? check.zone?.shortName ?? check.zoneLine
        return [ahead.map(Adesso.aheadLine), city?.localizedName, where_].compactMap { $0 }.joined(separator: " · ")
    }

    private func actions(_ check: PlaceCheck) -> some View {
        VStack(spacing: 10) {
            if check.parkingFirst {
                // 1.19.1: «Non entrare.» → l'azione principale è «Parcheggia fuori e cammina», grande e per prima;
                // la mappa diventa un pulsante secondario accanto a «Perché?» e «Dettagli del viaggio»
                parkButton(primary: true, place: check.place)
                HStack(spacing: 10) {
                    Button { openMap(check) } label: {
                        Image(systemName: "map.fill").font(.app(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                            .frame(width: 52, height: Theme.Target.minimum)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("See the map"))
                    .accessibilityIdentifier("varco.map")
                    whyAndDetails(check)
                }
            } else {
                Button { openMap(check) } label: {
                    Label(L("See the map"), systemImage: "map.fill")
                        .font(Self.font(18, .bold)).foregroundStyle(Theme.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: Theme.Target.standard)
                        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("varco.map")
                HStack(spacing: 10) { whyAndDetails(check) }
                // Ambra (sotto «Perché?» e «Dettagli», che devono stare nello schermo): i parcheggi fuori dalla ZTL, con i minuti a piedi
                if check.suggestsParking { parkButton(primary: false, place: check.place) }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func whyAndDetails(_ check: PlaceCheck) -> some View {
        if let hit = check.hit {
            secondary(L("Why?"), "doc.text") {
                store.cityId = hit.city.id; store.zoneId = hit.zone.id
                showZone = true
            }
            .accessibilityIdentifier("varco.why")
        }
        secondary(L("Trip details"), "suitcase.rolling") {
            if store.place == nil { store.select(check.place) }
            router.tab = .trip
        }
        .accessibilityIdentifier("varco.details")
    }

    /// «Parcheggia fuori e cammina»: principale (più grande, per primo) quando la risposta è «no». 2.3: il pulsante
    /// principale chiaro su Notte e scuro su Giorno, il secondario con il bordo; mai rosso (S-Componenti)
    private func parkButton(primary: Bool, place: Place) -> some View {
        Button { parkPlace = place; parkSheet = true } label: {
            Label(L("Park outside and walk"), systemImage: "figure.walk")
                .font(primary ? Self.font(18, .bold) : Font.app(size: 16, weight: .bold))
                .foregroundStyle(primary ? Theme.onPrimary : Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: Theme.Target.standard)
                .background(primary ? Theme.primary : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { if !primary { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 2) } }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("varco.park")
    }

    private func secondary(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.app(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: Theme.Target.minimum)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    /// 2.2 La modalità «In auto» (tavola I-InAuto): la risposta per dove sei, a tutto schermo e con le parole grandi
    private var inCarButton: some View {
        Button { router.inCar = true } label: {
            Label(L("In the car"), systemImage: "car.fill")
                .font(.app(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: Theme.Target.standard)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint(L("The answer where you are, in big letters"))
        .accessibilityIdentifier("varco.incar")
    }

    /// Senza un posto: la domanda, con gli hotel dei viaggi e i posti recenti a un tocco
    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Can I drive in?").uppercased())
                .font(Self.font(13, .bold)).kerning(1.4).foregroundStyle(Theme.muted)
            // Una riga per parte, strette (con «\n» l'interlinea del carattere le allontanava troppo)
            VStack(alignment: .leading, spacing: -6) {
                ForEach(L("Find out if you|can drive in").components(separatedBy: "|"), id: \.self) {
                    Text(verbatim: $0).font(Self.font(36, .black)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Find out if you|can drive in").replacingOccurrences(of: "|", with: " "))
            .accessibilityAddTraits(.isHeader)
            Text("Search a hotel, address or square: GateLR tells you at once if your car can get there.")
                .font(.app(size: 15)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            let hotels = Self.savedHotels(store.trips)
            let recent = store.recent.filter { p in !hotels.contains { $0.key == p.key } }.prefix(max(0, 4 - hotels.count))
            if !hotels.isEmpty || !recent.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(hotels) { p in
                            chip(String(format: L("Your hotel · %@"), p.name), symbol: "suitcase.rolling.fill", highlighted: true) { store.select(p) }
                                .accessibilityIdentifier("varco.hotel")
                        }
                        ForEach(Array(recent)) { p in
                            chip(p.name, symbol: "clock.arrow.circlepath", highlighted: false) { store.select(p) }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    private func chip(_ title: String, symbol: String, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Label { Text(verbatim: title) } icon: { Image(systemName: symbol) }
                .font(.app(size: 13, weight: .semibold)).lineLimit(1)
                .padding(.horizontal, 12).frame(height: 32)
                .frame(minHeight: Theme.Target.minimum)
                .background(highlighted ? Theme.primary : Theme.raised, in: Capsule().inset(by: 6))
                .foregroundStyle(highlighted ? Theme.onPrimary : Theme.ink)
        }
        .buttonStyle(.plain)
    }

    /// Gli hotel dei viaggi salvati, al massimo due: prima i viaggi non ancora finiti (dal più vicino), poi gli ultimi salvati
    static func savedHotels(_ trips: [Trip], now: Date = Date()) -> [Place] {
        let open = trips.filter { $0.departure > now }.sorted { $0.arrival < $1.arrival }
        let past = trips.filter { $0.departure <= now }
        var out: [Place] = []
        for t in open + past {
            guard var h = t.hotel, !out.contains(where: { $0.key == h.key }) else { continue }
            if !t.hotelName.isEmpty { h.name = t.hotelName }
            out.append(h)
            if out.count == 2 { break }
        }
        return out
    }

    // MARK: Sotto la risposta

    /// Solo una riga: la ZTL vicino a te (o quella in cui sei), se adesso è attiva
    @ViewBuilder
    private func nearYou(at date: Date) -> some View {
        if let here = monitor.answerLocation {
            let c = Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude)
            let inside = store.zones(at: c).first
            let near = store.nearestZone(to: c)
            let nearby: Zone? = (near?.meters ?? .infinity) < 30_000 ? near?.zone : nil
            if let zone = inside?.zone ?? nearby {
                let a = store.answer(at: date, zone: zone, hotelInside: false), on = a.gatesOn
                // 2.1 (B26): il colore dalla RispostaFinale (dati non sicuri o fonte non ufficiale: ambra, mai verde)
                let tint = RispostaFinale.of(a, zone: zone).stato.tint
                let distance = inside != nil ? L("you're inside") : DriveSession.distanceText(near?.meters ?? 0)
                Button { select(zone); showZone = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill").font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                        (Text(verbatim: L("Near you") + ": ").foregroundStyle(Theme.muted)
                         + Text(verbatim: "\(zone.shortName) · \(distance) · ").foregroundStyle(Theme.ink)
                         + Text(verbatim: on ? L("active now") : L("not active now")).foregroundStyle(tint))
                            .font(.app(size: 14, weight: .medium)).lineLimit(2).minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.app(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Simbolo, testo e colore del riquadro del guardiano (testabile)
    /// 2.0 (B13): «waiting»: acceso ma ancora senza una posizione precisa, neutro «In attesa del GPS…» (mai il riposo).
    /// 2.0 (B67): l'ambra del riquadro è scura (#946600, 5:1 con il testo bianco; prima #B07A00, 3,7:1)
    static func guardianLook(threat: Guardian.Threat?, resting: ThreatResting, waiting: Bool = false) -> (symbol: String, text: String, fill: Color) {
        if waiting { return ("location.slash", L("Waiting for GPS…"), Color(hex: 0x3A4A6B)) }
        if let t = threat {
            let text = "\(t.candidate.pedestrian != nil ? t.zone.localizedName : t.zone.shortName) · \(DriveSession.distanceText(t.meters)) · \(t.spoken)"
            switch t.level {
            case .stop: return ("exclamationmark.shield.fill", text, Theme.redFill)
            case .condition, .check, .clear: return ("shield.lefthalf.filled", text, Self.guardianAmber)
            }
        }
        switch resting {
        // 1.20.4: grigio con lo scudo vuoto, come la Live Activity (la spunta diceva «sì»)
        case .clear: return ("shield", L("No active ZTL ahead"), Color(hex: 0x5B6476))
        case .unknownPlace: return ("shield", L("We don't know the ZTLs of this place"), Color(hex: 0x3A4A6B))
        }
    }

    /// L'ambra scura dei riquadri con il testo bianco (B67: almeno 4,5:1)
    static let guardianAmber = Color(hex: 0x946600)

    private func tripRow(_ t: Trip) -> some View {
        Button {
            if let h = t.hotel { store.select(h) }
            router.tab = .trip
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "suitcase.rolling.fill").foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40).background(Theme.raised, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your next trip").font(.app(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                    Text(t.hotelName.isEmpty ? (t.hotel?.name ?? L("Trip")) : t.hotelName)
                        .font(.app(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(store.engine.format(t.arrival, .dateTime.weekday(.wide).day().month().hour().minute()))
                        .font(.app(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.app(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// «Parcheggia fuori e cammina» per il posto della risposta (lo stesso foglio della mappa)
    @ViewBuilder
    private var parkOutsideSheet: some View {
        if let place = parkPlace {
            ScrollView {
                ParkOutsideCard(destination: place, arrival: store.moment(), onStart: { target in
                    parkSheet = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        await DriveSession.shared.start(to: target, store: store)
                        driving = DriveSession.shared.active
                    }
                }, onGuardian: { target, navigator in
                    parkSheet = false
                    Guardian.shared.start(to: target, with: navigator, store: store)
                })
                .padding(16)
            }
            .background(Theme.ground)
            .presentationDetents([.medium, .large])
            .environmentObject(store)
        }
    }

    private func select(_ z: Zone) {
        if let city = store.cities.first(where: { $0.zones.contains(z) }) { store.cityId = city.id }
        store.zoneId = z.id
    }

    /// Titillium Web come i cartelli, che cresce con «Testo più grande» fino a +30% (come Font.app)
    static func font(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        Notte.font(size, weight)       // 2.0 (B38): il tetto una volta sola (Notte.font), poi misura fissa
    }
}

/// 1.19.5: il riquadro del guardiano in Varco, l'unica parte della pagina che osserva Guardian (la distanza cambia a ogni
/// posizione: prima si ridisegnava tutta la pagina, ora solo questo riquadro)
private struct GuardianBannerSlot: View {
    @ObservedObject private var guardian = Guardian.shared

    /// Il guardiano è attivo: cosa vede adesso e il pulsante per fermarlo. 1.19.3: con le parole e il colore della
    /// risposta (rosso, giallo); senza zone davanti grigio «Nessuna ZTL attiva davanti», fuori dalle città che conosciamo
    /// neutro «Non conosciamo le ZTL di questo posto» (prima era sempre verde, anche dove non sapevamo niente)
    var body: some View {
        if guardian.active { banner }
    }

    private var banner: some View {
        let look = VarcoView.guardianLook(threat: guardian.threat, resting: guardian.resting, waiting: guardian.waitingForFix)
        return HStack(spacing: 12) {
            Image(systemName: look.symbol).font(.app(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: L("Guardian on · to %@"), guardian.destination?.name ?? "")).font(.app(size: 15, weight: .bold)).lineLimit(1)
                Text(verbatim: look.text).font(.app(size: 13)).opacity(0.9).lineLimit(2)
            }
            Spacer()
            Button(L("Stop")) { guardian.stop() }
                .font(.app(size: 14, weight: .bold))
                .padding(.horizontal, 12).frame(height: 34)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(look.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guardian.banner")
    }
}

/// 1.19.5: lo scheletro della striscia di mappa mentre Mapbox si carica: il blu notte con qualche via accennata,
/// fermo (nessuna animazione) e neutro (mai il colore di una risposta)
struct MapStripSkeleton: View {
    var body: some View {
        ZStack {
            Theme.card
            Canvas { ctx, size in
                let streets: [(CGPoint, CGPoint, CGFloat)] = [
                    (CGPoint(x: 0, y: 0.62), CGPoint(x: 1, y: 0.38), 7), (CGPoint(x: 0.18, y: 0), CGPoint(x: 0.42, y: 1), 5),
                    (CGPoint(x: 0.64, y: 0), CGPoint(x: 0.86, y: 1), 4), (CGPoint(x: 0, y: 0.22), CGPoint(x: 0.6, y: 0.05), 3),
                    (CGPoint(x: 0.3, y: 1), CGPoint(x: 1, y: 0.8), 3),
                ]
                for (a, b, w) in streets {
                    var p = Path()
                    p.move(to: CGPoint(x: a.x * size.width, y: a.y * size.height))
                    p.addLine(to: CGPoint(x: b.x * size.width, y: b.y * size.height))
                    ctx.stroke(p, with: .color(Theme.line), lineWidth: w)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// La striscia di mappa senza Mapbox: la mappa di Apple scura, inclinata, con le zone velate del colore della risposta
private struct VarcoAppleStrip: View {
    var place: Place
    var focus: Zone?
    /// Le zone per colore e stato (attiva o no), ognuna con la sua risposta
    var zones: [AccessCache.Look: [[CLLocationCoordinate2D]]]
    var tint: Color
    var marker: StripMarkerKind?
    var framing: StripFrame
    /// Il pallino blu di iOS, solo con il permesso della posizione
    var showsUser: Bool
    /// 2.3: il tema del telefono (le zone con i toni scuri o chiari)
    var dark = true

    var body: some View {
        Map(initialPosition: position, interactionModes: []) {
            // 1.20.4 (memoria): senza le righe a 45° delle zone attive. Erano fino a 80 MapPolyline per zona (a Firenze lo
            // Scudo Verde è sempre attivo): MapKit le ridisegnava a ogni minuto (TimelineView di Varco) e la memoria saliva
            // da 100 a 250 MB e ritorno, a ondate, con o senza guardiano (MisureTests.testM7a e testM7e). Il colore della zona
            // dice già la risposta; le righe restano sulla Mappa e nella striscia di Mapbox
            ForEach(Self.layers(zones)) { z in
                ZoneOverlay(coords: z.ring, access: z.look.access, picked: false, dim: false, big: false, zoom: 16, dark: dark)
            }
            // Il cartello della ZTL o lo spillo della destinazione, con la base sul posto: mai un pallino
            if let marker {
                Annotation("", coordinate: place.location.cl, anchor: .bottom) {
                    StripMarker(kind: marker, tint: tint)
                }
                .annotationTitles(.hidden)
            }
            if showsUser {
                UserAnnotation()
            }
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll))
        // Una mappa nuova quando cambia il posto o la zona (la camera iniziale non si sposta da sola)
        // (e quando la tua posizione entra o esce dalla ripresa, o si sposta di qualche centinaio di metri)
        .id("\(place.location.lat),\(place.location.lon),\(focus?.id ?? ""),\(framing.includesUser),\(Int(framing.center.lat * 500)),\(Int(framing.center.lon * 500))")
    }

    private struct Layer: Identifiable {
        var id: String
        var look: AccessCache.Look
        var ring: [CLLocationCoordinate2D]
    }

    /// Grigio e verde sotto, rosso sopra (Home2Map.Coordinator.order)
    private static func layers(_ zones: [AccessCache.Look: [[CLLocationCoordinate2D]]]) -> [Layer] {
        Home2Map.Coordinator.order(zones.keys).flatMap { look in
            (zones[look] ?? []).enumerated().map { Layer(id: "\(look.access)-\(look.active)-\($0.offset)", look: look, ring: $0.element) }
        }
    }

    private var position: MapCameraPosition {
        if framing.includesUser {
            let d = framing.degrees
            return .region(MKCoordinateRegion(center: framing.center.cl, span: MKCoordinateSpan(latitudeDelta: d.lat, longitudeDelta: d.lon)))
        }
        if let focus, focus.widthMeters < 6_000 { return .region(focus.region(padding: 1.2)) }
        return .camera(MapCamera(centerCoordinate: place.location.cl, distance: 1_800, heading: 340, pitch: 55))
    }
}
