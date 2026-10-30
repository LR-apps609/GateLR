import SwiftUI
import MapKit
import StoreKit
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
    @ObservedObject private var guardian = Guardian.shared
    @StateObject private var search = AddressSearch()
    @Binding var showZone: Bool
    @Binding var tab: Tab
    @FocusState private var typing: Bool
    @State private var resolving = false
    @State private var mapFailed = !NotteMap.hasToken
    @State private var parkSheet = false
    @State private var driving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let moment = store.moment(ctx.date)
            let check = subject.map { PlaceCheck($0, store: store, at: moment) }
            let answer = check.map { Home2Answer($0, now: ctx.date) }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    mapStrip(check: check, mood: answer?.mood ?? cityMood(at: moment), at: moment)
                    ContextChips(material: true)
                    if guardian.active { guardianBanner }
                    searchField
                    if typing && !search.query.isEmpty {
                        suggestions
                    } else {
                        if let check, let answer {
                            answerCard(check, answer)
                        } else {
                            emptyCard
                        }
                        nearYou(at: moment)
                        if let next = store.trips.filter({ $0.arrival > ctx.date }).min(by: { $0.arrival < $1.arrival }) { tripRow(next) }
                        StatusBanner(status: store.city.status, unofficial: store.city.hasUnofficialZones)
                        Text("Road signs on site always win over the app.")
                            .font(.app(size: 12)).foregroundStyle(Notte.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 24)
                .readableFrame()
                .animation(.snappy, value: store.place)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(sceneBackground(answer?.mood).ignoresSafeArea())
        }
        // Il blu notte dell'identità anche con il telefono in modalità chiara (solo questa scheda: la barra resta di iOS)
        .environment(\.colorScheme, .dark)
        .onAppear { search.focus(on: store.city) }
        .onChange(of: store.cityId) { search.focus(on: store.city) }
        .sheet(isPresented: $parkSheet) { parkOutsideSheet }
        .fullScreenCover(isPresented: $driving) { DriveView() }
        // La recensione su App Store: 2 secondi dopo la risposta alla prima ricerca di un posto o di un hotel (ReviewPrompter)
        .onChange(of: store.place) { _, place in
            guard let place, place.name != L("My position") else { return }
            Task { @MainActor in
                try? await Task.sleep(for: ReviewPrompter.delay)
                let blocked = store.place != place || router.tab != .varco || router.showIntro || driving || parkSheet
                    || showZone || DriveSession.shared.active
                guard ReviewPrompter.shouldRequest(blocked: blocked) else { return }
                ReviewPrompter.recordRequest()
                requestReview()
            }
        }
    }

    // MARK: Il posto della risposta

    /// Il posto cercato; se non c'è, la tua posizione quando sei dentro una ZTL
    private var subject: Place? {
        if let p = store.place { return p }
        guard let here = monitor.location else { return nil }
        let c = Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude)
        guard !store.zones(at: c).isEmpty else { return nil }
        return Place(name: L("My position"), address: "", location: c)
    }

    /// Senza un posto: rosso se la zona scelta è attiva adesso, verde se no
    private func cityMood(at date: Date) -> Home2Answer.Mood {
        store.answer(at: date, zone: store.zone, hotelInside: false).gatesOn ? .red : .green
    }

    private func sceneBackground(_ mood: Home2Answer.Mood?) -> some View {
        ZStack {
            Notte.navy
            // La luce del pannello che cade sulla pagina, dall'alto
            if let mood {
                RadialGradient(colors: [mood.color.opacity(0.28), mood.color.opacity(0.06), .clear],
                               center: UnitPoint(x: 0.5, y: 0.42), startRadius: 10, endRadius: 460)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Wordmark(size: 20)
            Spacer()
            Menu {
                ForEach(store.cities) { c in
                    Button(c.localizedName) { store.place = nil; store.cityId = c.id }
                }
            } label: {
                Label(store.city.localizedName, systemImage: "building.2")
                    .font(.app(size: 13, weight: .semibold)).lineLimit(1)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(Notte.text)
            }
            .accessibilityLabel(String(format: L("City: %@"), store.city.localizedName))
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
    private func mapStrip(check: PlaceCheck?, mood: Home2Answer.Mood, at moment: Date) -> some View {
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
        let height: CGFloat = check == nil ? 168 : 112
        let framing = StripFrame.make(target: place.location, user: user)
        return ZStack(alignment: .bottomLeading) {
            Group {
                if mapFailed {
                    VarcoAppleStrip(place: place, focus: check?.zone ?? (check == nil ? store.zone : nil),
                                    zones: rings, tint: mood.color, marker: marker, framing: framing, showsUser: user != nil)
                } else {
                    Home2Map(place: place, zones: rings, mood: mood, mapMode: false, reduceMotion: reduceMotion,
                             ornamentBottom: 6, focusBottom: 0, marker: marker, user: user, stripPoints: height,
                             onFail: { mapFailed = true })
                }
            }
            .accessibilityHidden(true)
            LinearGradient(colors: [.clear, Notte.navy.opacity(0.55)], startPoint: .center, endPoint: .bottom)
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
                .font(.app(size: 12, weight: .bold)).foregroundStyle(Notte.text)
                .padding(.horizontal, 10).frame(height: 26)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.leading, 10).padding(.bottom, 34)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        // Più bassa quando c'è una risposta: la risposta e i suoi pulsanti stanno nello schermo
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(mood.color.opacity(0.55), lineWidth: 1))
        .shadow(color: mood.color.opacity(0.25), radius: 18, y: 6)
    }

    /// La scheda Mappa sulla zona della risposta (la mappa va sul posto scelto o sulla zona scelta, vedi MapScreen.focus)
    private func openMap(_ check: PlaceCheck?) {
        if let hit = check?.hits.first { store.cityId = hit.city.id; store.zoneId = hit.zone.id }
        tab = .map
    }

    // MARK: Ricerca

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.app(size: 17, weight: .semibold)).foregroundStyle(Notte.action)
            TextField("", text: $search.query,
                      prompt: Text(L("Hotel, address or square")).foregroundColor(Notte.muted))
                .focused($typing)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .foregroundStyle(Notte.text)
                .accessibilityLabel(L("Hotel, address or square"))
                .accessibilityIdentifier("varco.search")
            if resolving { ProgressView() }
            if !search.query.isEmpty {
                Button { search.clear(); typing = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Notte.muted)
                }
                .accessibilityLabel(L("Clear"))
            } else if monitor.location != nil {
                Button { useMyLocation() } label: { Image(systemName: "location.fill").foregroundStyle(Notte.text) }
                    .accessibilityLabel(L("Use my location"))
            }
        }
        .font(.app(size: 17))
        .padding(.horizontal, 14).frame(minHeight: 52)
        .background(Notte.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(typing ? Notte.action : Notte.line, lineWidth: typing ? 2 : 1))
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            if search.results.isEmpty {
                Text(search.failed ? L("Search isn't working right now. Check your connection.") : L("Keep typing…"))
                    .font(.app(size: 14)).foregroundStyle(Notte.muted).padding(14)
            }
            ForEach(Array(search.results.enumerated()), id: \.offset) { i, r in
                Button { choose(r) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill").font(.app(size: 22)).foregroundStyle(Notte.action)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title).font(.app(size: 15, weight: .semibold)).foregroundStyle(Notte.text).lineLimit(1)
                            if !r.subtitle.isEmpty {
                                Text(r.subtitle).font(.app(size: 13)).foregroundStyle(Notte.muted).lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("varco.result.\(i)")
                if i < search.results.count - 1 { Divider().overlay(Notte.line).padding(.leading, 48) }
            }
        }
        .background(Notte.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        guard let here = monitor.location else { return }
        store.select(Place(name: L("My position"), address: "",
                           location: Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude)))
    }

    // MARK: La risposta

    private func answerCard(_ check: PlaceCheck, _ a: Home2Answer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            placeRow(check)
            if a.unofficial { UnofficialBanner(source: a.unofficialSource) }
            // Solo la scatola dei punti luminosi, senza palo: la pagina più corta, così «Guarda la mappa», «Perché?» e
            // «Dettagli del viaggio» si vedono senza scorrere anche su iPhone Pro Max (vedi ScreenshotTests.test5VarcoProMax)
            // Più piccolo dalla 1.17.3: sopra c'è il nome del posto
            GatePanelObject(panel: a.panel, showsPole: false)
                .scaleEffect(0.64)
                .frame(maxWidth: .infinity)
                .frame(height: 92)
            Text(a.headline)
                .font(Self.font(44, .black)).foregroundStyle(Notte.text)
                .lineLimit(2).minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("varco.answer")
                .id(a.headline)
                .transition(.opacity.combined(with: .offset(y: 8)))
            // La condizione (o il motivo del dubbio) subito sotto il titolo, in testo normale
            if let detail = a.detail {
                Text(verbatim: detail)
                    .font(.app(size: 17, weight: .medium)).foregroundStyle(Notte.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -6)
                    .accessibilityIdentifier("varco.condition")
            }
            if let label = a.timeLabel {
                timeBlock(label, a)
            }
            actions(check)
            // Città e zona sono già sotto il titolo: qui resta solo l'ora scelta
            if store.when != nil {
                Text(verbatim: String(format: L("For %@"), TimeChoice.label(store.when)))
                    .font(.app(size: 13, weight: .semibold)).foregroundStyle(Notte.muted)
            }
            // «Segnala un errore» per la zona della risposta
            if let hit = check.hits.first {
                ReportErrorButton(zone: hit.zone, city: hit.city, onDark: true)
                    .accessibilityIdentifier("varco.report")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [a.mood.color.opacity(0.2), .clear], startPoint: .top, endPoint: .center))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(LinearGradient(colors: [a.mood.color.opacity(0.75), Color.white.opacity(0.1)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.5), value: a.mood)
    }

    private func timeBlock(_ label: String, _ a: Home2Answer) -> some View {
        VStack(alignment: .leading, spacing: -4) {
            Text(label.uppercased()).font(Self.font(13, .bold)).kerning(1.4).foregroundStyle(Notte.muted)
            if let time = a.time {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: time)
                        .font(Self.font(56, .black)).monospacedDigit()
                        .foregroundStyle(Notte.text)
                        .shadow(color: a.mood.color.opacity(0.55), radius: 20)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                    if let day = a.day {
                        Text(verbatim: day).font(Self.font(18, .semibold)).foregroundStyle(Notte.muted)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Il posto, con i recenti e gli hotel dei viaggi a un tocco, e la croce per tornare alla domanda
    private func placeRow(_ check: PlaceCheck) -> some View {
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
                            .font(Self.font(30, .black)).foregroundStyle(Notte.text)
                            .lineLimit(2).minimumScaleFactor(0.75)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.down").font(.app(size: 14, weight: .bold))
                            .foregroundStyle(Notte.text.opacity(0.7))
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: placeSubtitle(check))
                        .font(.app(size: 14, weight: .semibold)).foregroundStyle(Notte.muted)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(Self.placeTitle(check)), \(placeSubtitle(check))")
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("varco.place")
            Spacer(minLength: 4)
            if store.place != nil {
                Button { withAnimation(.snappy) { store.place = nil } } label: {
                    Image(systemName: "xmark").font(.app(size: 13, weight: .bold)).foregroundStyle(Notte.text)
                        .frame(width: 32, height: 32).background(Color.white.opacity(0.14), in: Circle())
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

    /// La riga sotto il titolo: città e zona («Firenze · Settore A»), l'area pedonale o «Fuori dalla ZTL»
    private func placeSubtitle(_ check: PlaceCheck) -> String {
        let city = check.hits.first?.city ?? store.nearestCity(to: check.place.location)
        let where_ = check.pedestrian?.name ?? check.zone?.shortName ?? L("Outside the ZTL")
        return [city?.localizedName, where_].compactMap { $0 }.joined(separator: " · ")
    }

    private func actions(_ check: PlaceCheck) -> some View {
        VStack(spacing: 10) {
            Button { openMap(check) } label: {
                Label(L("See the map"), systemImage: "map.fill")
                    .font(Self.font(18, .bold)).foregroundStyle(Notte.navy)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Notte.text, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("varco.map")
            HStack(spacing: 10) {
                if let hit = check.hits.first {
                    secondary(L("Why?"), "doc.text") {
                        store.cityId = hit.city.id; store.zoneId = hit.zone.id
                        showZone = true
                    }
                    .accessibilityIdentifier("varco.why")
                }
                secondary(L("Trip details"), "suitcase.rolling") {
                    if store.place == nil { store.select(check.place) }
                    router.open(.trip)
                }
                .accessibilityIdentifier("varco.details")
            }
            // Rosso o ambra (sotto «Perché?» e «Dettagli», che devono stare nello schermo): i parcheggi fuori dalla ZTL, con i minuti a piedi
            if check.suggestsParking {
                Button { parkSheet = true } label: {
                    Label(L("Park outside and walk"), systemImage: "figure.walk")
                        .font(.app(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Notte.action, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("varco.park")
            }
        }
        .padding(.top, 4)
    }

    private func secondary(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.app(size: 14, weight: .semibold)).foregroundStyle(Notte.text)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Senza un posto: la domanda, con gli hotel dei viaggi e i posti recenti a un tocco
    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Can I drive in?").uppercased())
                .font(Self.font(13, .bold)).kerning(1.4).foregroundStyle(Notte.muted)
            // Una riga per parte, strette (con «\n» l'interlinea del carattere le allontanava troppo)
            VStack(alignment: .leading, spacing: -6) {
                ForEach(L("Find out if you|can drive in").components(separatedBy: "|"), id: \.self) {
                    Text(verbatim: $0).font(Self.font(36, .black)).foregroundStyle(Notte.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Find out if you|can drive in").replacingOccurrences(of: "|", with: " "))
            .accessibilityAddTraits(.isHeader)
            Text("Search a hotel, address or square: GateLR tells you at once if your car can get there.")
                .font(.app(size: 15)).foregroundStyle(Notte.muted)
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
        .background(Notte.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Notte.line, lineWidth: 1))
    }

    private func chip(_ title: String, symbol: String, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Label { Text(verbatim: title) } icon: { Image(systemName: symbol) }
                .font(.app(size: 13, weight: .semibold)).lineLimit(1)
                .padding(.horizontal, 12).frame(height: 32)
                .background(highlighted ? Notte.action : Color.white.opacity(0.1), in: Capsule())
                .foregroundStyle(Notte.text)
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
        if let here = monitor.location {
            let c = Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude)
            let inside = store.zones(at: c).first
            let near = store.nearestZone(to: c)
            let nearby: Zone? = (near?.meters ?? .infinity) < 30_000 ? near?.zone : nil
            if let zone = inside?.zone ?? nearby {
                let on = store.answer(at: date, zone: zone, hotelInside: false).gatesOn
                let distance = inside != nil ? L("you're inside") : DriveSession.distanceText(near?.meters ?? 0)
                Button { select(zone); showZone = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill").font(.app(size: 13, weight: .semibold)).foregroundStyle(Notte.text)
                        (Text(verbatim: L("Near you") + ": ").foregroundStyle(Notte.muted)
                         + Text(verbatim: "\(zone.shortName) · \(distance) · ").foregroundStyle(Notte.text)
                         + Text(verbatim: on ? L("active now") : L("not active now")).foregroundStyle(on ? Notte.ledRed : Notte.ledGreen))
                            .font(.app(size: 14, weight: .medium)).lineLimit(2).minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.app(size: 12, weight: .bold)).foregroundStyle(Notte.muted)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Notte.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Il guardiano è attivo: cosa vede adesso e il pulsante per fermarlo
    private var guardianBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled").font(.app(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: L("Guardian on · to %@"), guardian.destination?.name ?? "")).font(.app(size: 15, weight: .bold)).lineLimit(1)
                Text(guardian.threat.map { "\($0.zone.shortName) · \(DriveSession.distanceText($0.meters)) · \($0.answer.verdict.shortText(unofficial: $0.zone.isUnofficial))" }
                     ?? L("No active ZTL ahead"))
                    .font(.app(size: 13)).opacity(0.9)
            }
            Spacer()
            Button(L("Stop")) { guardian.stop() }
                .font(.app(size: 14, weight: .bold))
                .padding(.horizontal, 12).frame(height: 34)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(guardian.threat == nil ? Theme.green : Theme.red, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func tripRow(_ t: Trip) -> some View {
        Button {
            if let h = t.hotel { store.select(h) }
            router.open(.trip)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "suitcase.rolling.fill").foregroundStyle(Notte.text)
                    .frame(width: 40, height: 40).background(Notte.action, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your next trip").font(.app(size: 12, weight: .semibold)).foregroundStyle(Notte.muted)
                    Text(t.hotelName.isEmpty ? (t.hotel?.name ?? L("Trip")) : t.hotelName)
                        .font(.app(size: 16, weight: .semibold)).foregroundStyle(Notte.text).lineLimit(1)
                    Text(store.engine.format(t.arrival, .dateTime.weekday(.wide).day().month().hour().minute()))
                        .font(.app(size: 13)).foregroundStyle(Notte.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.app(size: 13, weight: .bold)).foregroundStyle(Notte.muted)
            }
            .padding(14)
            .background(Notte.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// «Parcheggia fuori e cammina» per il posto della risposta (lo stesso foglio della mappa)
    @ViewBuilder
    private var parkOutsideSheet: some View {
        if let place = subject {
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
        Notte.font(min(size * 1.3, UIFontMetrics.default.scaledValue(for: size)), weight)
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

    var body: some View {
        Map(initialPosition: position, interactionModes: []) {
            ForEach(Self.layers(zones)) { z in
                ZoneOverlay(coords: z.ring, access: z.look.access, picked: false, dim: false, big: false, zoom: 16, dark: true)
                if z.look.active {
                    // solo intorno al posto (la striscia ne mostra poche centinaia di metri), al massimo 80 righe per zona
                    ForEach(HatchCache.lines(id: z.id, coords: z.ring, zoom: 16, box: stripBox, limit: 80)) { h in
                        MapPolyline(coordinates: [h.a, h.b])
                            .stroke(MapTheme.tone(z.look.access).line.opacity(MapTheme.hatchOpacity(dark: true)), lineWidth: 1)
                    }
                }
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

    private var stripBox: BBox {
        let c = framing.includesUser ? framing.center : place.location
        return BBox(minLat: c.lat - 0.006, minLon: c.lon - 0.008, maxLat: c.lat + 0.006, maxLon: c.lon + 0.008)
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
