import SwiftUI
import MapKit
import CoreLocation
import UserNotifications

// 1.20.2 «Comodità»: le piccole regole che rendono l'app più comoda, scritte qui una volta e provate nei test
// (Tests/ComoditaTests.swift): Invio nella ricerca, permessi al momento giusto, conferma prima di cancellare,
// i tempi della mappa di riserva e il raggio dei parcheggi di Apple.

// MARK: Ricerca: Invio e «Riprova»

/// Cosa fa il tasto Invio («Cerca» sulla tastiera) nel campo di ricerca
enum SearchSubmit: Equatable {
    /// C'è almeno un suggerimento: si sceglie il primo, come toccarlo
    case pickFirst
    /// La ricerca non ha avuto risposta (rete): si riprova, e si sceglie il primo appena arriva
    case retry
    /// I suggerimenti stanno arrivando: si sceglie il primo appena arriva
    case wait
    /// Troppo poco da cercare (meno di 2 lettere): niente
    case nothing

    static func action(query: String, results: Int, failed: Bool) -> SearchSubmit {
        guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { return .nothing }
        if results > 0 { return .pickFirst }
        return failed ? .retry : .wait
    }
}

/// Sotto il campo di ricerca quando la ricerca non risponde: il motivo e «Riprova» (Varco e presentazione sul blu
/// notte, Mappa e Viaggio sul chiaro)
struct SearchFailedRow: View {
    var dark: Bool
    var retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("Search isn't working right now. Check your connection.")
                .font(.app(size: 14)).foregroundStyle(dark ? Notte.muted : Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action: retry) {
                Label(L("Try again"), systemImage: "arrow.clockwise")
                    .font(.app(size: 14, weight: .semibold))
                    .padding(.horizontal, 12).frame(minHeight: 36)
                    .background((dark ? Color.white.opacity(0.14) : Theme.blueSoft), in: Capsule())
                    .foregroundStyle(dark ? Notte.text : Theme.blue)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("search.retry")
        }
        .padding(14)
    }
}

// MARK: Permessi al momento giusto

/// Quando l'app usa una cosa che ha bisogno di un permesso di iOS
enum PermissionMoment: CaseIterable {
    /// L'app si apre (anche dopo la presentazione): non si chiede niente
    case launch
    /// «Usa la mia posizione» (Varco): la posizione mentre usi l'app
    case useMyLocation
    /// «Attiva gli avvisi» (presentazione) e «Consenti gli avvisi» (Impostazioni): notifiche e posizione «Sempre»
    case turnOnAlerts
    /// La guida di GateLR: la posizione mentre usi l'app
    case drive
    /// Il guardiano con un altro navigatore: posizione «Sempre» e notifiche
    case guardian
    /// Un promemoria (ticket, hotel): solo le notifiche
    case reminder
}

struct PermissionAsk: Equatable {
    enum Location: Equatable { case whenInUse, always }
    var location: Location?
    var notifications: Bool

    static let nothing = PermissionAsk(location: nil, notifications: false)
}

/// 1.20.2: i permessi si chiedono quando serve la cosa che li usa, mai all'apertura dell'app (prima, finita la
/// presentazione, arrivavano subito posizione, notifiche e «Sempre»). Nel giro delle foto mai: la richiesta di iOS
/// copriva la foto della guida (14-drive-milan-dark)
enum PermissionPolicy {
    static var uiTest: Bool { ProcessInfo.processInfo.arguments.contains("-uitest") }

    static func ask(at moment: PermissionMoment, uiTest: Bool = PermissionPolicy.uiTest) -> PermissionAsk {
        if uiTest { return .nothing }
        switch moment {
        case .launch: return .nothing
        case .useMyLocation, .drive: return PermissionAsk(location: .whenInUse, notifications: false)
        case .turnOnAlerts, .guardian: return PermissionAsk(location: .always, notifications: true)
        case .reminder: return PermissionAsk(location: nil, notifications: true)
        }
    }

    /// La posizione si può usare senza chiedere (già permessa)
    static func allowed(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    /// Fa le richieste di iOS di quel momento (quelle già decise non compaiono più: iOS le ignora)
    @MainActor
    static func request(_ moment: PermissionMoment, manager: CLLocationManager) async {
        let a = ask(at: moment)
        switch a.location {
        case .whenInUse?: if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        case .always?: manager.requestAlwaysAuthorization()
        case nil: break
        }
        if a.notifications {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }
}

// MARK: Conferma prima di cancellare

/// 1.20.2: quello che stai per cancellare, in attesa del «Elimina» nel dialogo (prima un colpo di dito bastava)
enum PendingDelete: Identifiable, Equatable {
    case vehicles(Set<UUID>)
    case permits(Set<UUID>)
    case logEntries(Set<UUID>)
    case trip(UUID)

    var id: String {
        switch self {
        case .vehicles(let s): "v" + s.map(\.uuidString).sorted().joined()
        case .permits(let s): "p" + s.map(\.uuidString).sorted().joined()
        case .logEntries(let s): "l" + s.map(\.uuidString).sorted().joined()
        case .trip(let id): "t" + id.uuidString
        }
    }

    /// La domanda del dialogo
    var title: String {
        switch self {
        case .vehicles(let s): s.count == 1 ? L("Delete this vehicle?") : String(format: L("Delete %lld vehicles?"), s.count)
        case .permits(let s): s.count == 1 ? L("Delete this permit?") : String(format: L("Delete %lld permits?"), s.count)
        case .logEntries(let s): s.count == 1 ? L("Delete this row of the log?") : String(format: L("Delete %lld rows of the log?"), s.count)
        case .trip: L("Delete this trip?")
        }
    }

    /// Quello che succede anche al resto (i permessi del veicolo spariscono con lui)
    var message: String {
        switch self {
        case .vehicles: L("Its permits are deleted too. You can't undo this.")
        default: L("You can't undo this.")
        }
    }

    /// Cancella davvero: solo dopo «Elimina». Con il veicolo spariscono i suoi permessi; se era quello in uso si passa al primo
    @MainActor
    func apply(to store: Store) {
        switch self {
        case .vehicles(let gone):
            store.vehicles.removeAll { gone.contains($0.id) }
            store.forgetStayPermits(Set(store.permits.filter { gone.contains($0.vehicleId) }.map(\.id)))
            store.permits.removeAll { gone.contains($0.vehicleId) }
            if let id = store.activeVehicleId, gone.contains(id) { store.activeVehicleId = store.vehicles.first?.id }
        case .permits(let gone):
            store.permits.removeAll { gone.contains($0.id) }
            // 2.0 (B71): il soggiorno di quel permesso torna «Non chiesto» (prima la scheda diceva ancora «Confermato»)
            store.forgetStayPermits(gone)
        case .logEntries(let gone):
            store.log.removeAll { gone.contains($0.id) }
        case .trip(let id):
            // 2.0 (B71): con il viaggio spariscono il suo soggiorno, i permessi dell'hotel e il promemoria (se nessun altro
            // viaggio salvato va nello stesso hotel)
            let hotel = store.trips.first { $0.id == id }?.hotel
            store.trips.removeAll { $0.id == id }
            if let key = hotel?.key, !store.trips.contains(where: { $0.hotel?.key == key }) { store.removeStay(key: key) }
        }
    }
}

extension View {
    /// Il dialogo di conferma di iOS («Elimina» in rosso, «Annulla») per quello che stai per cancellare
    func confirmDelete(_ pending: Binding<PendingDelete?>, store: Store) -> some View {
        confirmationDialog(pending.wrappedValue?.title ?? "", isPresented: Binding(get: { pending.wrappedValue != nil },
                                                                                   set: { if !$0 { pending.wrappedValue = nil } }),
                           titleVisibility: .visible, presenting: pending.wrappedValue) { p in
            Button(L("Delete"), role: .destructive) { p.apply(to: store); pending.wrappedValue = nil }
                .accessibilityIdentifier("delete.confirm")
            Button(L("Cancel"), role: .cancel) { pending.wrappedValue = nil }
        } message: { p in
            Text(verbatim: p.message)
        }
    }
}

// MARK: Mappa di riserva e parcheggi di Apple

enum MapboxFallback {
    /// 1.20.2: senza lo stile di Mapbox dopo 5 secondi si passa alla mappa di Apple (prima 10 nella striscia di Varco e
    /// 9 nella presentazione): con la rete lenta la striscia vuota restava troppo
    static let seconds: Double = 5
}

enum ParkingFallback {
    /// 1.20.2: un solo lato per la ricerca dei parcheggi di Apple intorno alla destinazione (prima 3 km nel percorso di
    /// Viaggio e 4 km in «Parcheggia fuori e cammina»: due parcheggi diversi per la stessa meta). 4 km, cioè 2 km per
    /// parte: dal centro di una ZTL grande (Roma, Milano Area C, il Settore A di Firenze) con 3 km si restava spesso
    /// dentro la zona e non usciva nessun parcheggio fuori; più di 2 km a piedi non si propongono comunque (ParkOutside.rank)
    static let span: Double = 4_000

    static func region(around c: Coordinate) -> MKCoordinateRegion {
        MKCoordinateRegion(center: c.cl, latitudinalMeters: span, longitudinalMeters: span)
    }
}
