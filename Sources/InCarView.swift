import SwiftUI
import UIKit

/// 2.2 La modalità «In auto» (tavola I-InAuto, P24-Navigazione): la risposta di Adesso per DOVE SEI, a tutto schermo,
/// con le parole grandi (almeno 60 punti) e i pulsanti grandi. La zona in cui sei o la più vicina entro 300 m nella
/// direzione in cui vai (Adesso), i metri, la zona e fino a quando. «Parcheggia fuori» quando la risposta è «No».
/// Lo schermo resta acceso finché la modalità è aperta. Mai il posto cercato: in auto conta dove sei
struct InCarView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var monitor = GateMonitor.shared
    @State private var parkFor: Place?
    /// Lo schermo era già tenuto acceso da altri (la navigazione): allora non lo spegniamo uscendo
    @State private var idleWasDisabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let subject = Adesso.subject(store: store, place: nil, location: monitor.answerLocation, at: ctx.date)
            VStack(alignment: .leading, spacing: 18) {
                header
                Spacer(minLength: 8)
                if let subject {
                    answer(subject)
                } else {
                    waiting
                }
                Spacer(minLength: 8)
                if let subject, subject.check.parkingFirst {
                    Button { parkFor = subject.check.place } label: {
                        // 2.3: il pulsante principale chiaro su Notte, scuro su Giorno, mai rosso; almeno 76 punti in auto
                        Label(L("Park outside"), systemImage: "figure.walk")
                            .font(Theme.display(24, .bold)).foregroundStyle(Theme.onPrimary)
                            .frame(maxWidth: .infinity, minHeight: Theme.Target.carPrimary)
                            .background(Theme.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("incar.park")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.ground.ignoresSafeArea())
        }
        // 2.3 (direzione C): Giorno e Notte dal telefono, come il resto dell'app (tavola I-InAutoGiorno)
        .onAppear {
            idleWasDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear { if !idleWasDisabled { UIApplication.shared.isIdleTimerDisabled = false } }
        .sheet(item: $parkFor) { place in
            ScrollView {
                ParkOutsideCard(destination: place, arrival: Date(), onStart: { _ in parkFor = nil }, onGuardian: { target, navigator in
                    parkFor = nil
                    Guardian.shared.start(to: target, with: navigator, store: store)
                })
                .padding(16)
            }
            .background(Theme.ground)
            .presentationDetents([.medium, .large])
            .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(verbatim: Self.title(guardianOn: Guardian.shared.active))
                .font(Theme.label(15)).kerning(1.4).foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.ink)
                    .frame(width: Theme.Target.car, height: Theme.Target.car)
                    .background(Theme.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("Close"))
            .accessibilityIdentifier("incar.close")
        }
    }

    /// «IN AUTO», «IN AUTO · GUARDIANO» con il guardiano acceso
    static func title(guardianOn: Bool) -> String {
        (guardianOn ? L("In the car") + " · " + L("Guardian") : L("In the car")).uppercased()
    }

    /// 2.3 (tavole I-InAuto, I-InAutoGiorno): il blocco pieno della risposta, più di metà schermo, uguale di giorno e di
    /// notte; sotto i metri, il posto e la zona. VoiceOver legge il blocco in un colpo solo
    private func answer(_ s: Adesso.Subject) -> some View {
        let f = s.check.finale
        return VStack(alignment: .leading, spacing: 14) {
            RispostaBlock(stato: f.stato, title: f.title, line: Self.zoneLine(s.check), detail: f.reasonLine,
                          spokenExtra: s.aheadMeters.map(Adesso.aheadLine), size: .car, identifier: "incar.answer")
                .id(f.title)
                .transition(.opacity)
            if let m = s.aheadMeters {
                Text(verbatim: Adesso.aheadLine(m))
                    .font(Theme.display(40, .bold)).foregroundStyle(Theme.ink)
                    .lineLimit(2).minimumScaleFactor(0.6)
                    .accessibilityHidden(true)
            }
            Text(verbatim: VarcoView.placeTitle(s.check))
                .font(Theme.display(26, .semibold)).foregroundStyle(Theme.ink)
                .lineLimit(2).minimumScaleFactor(0.7)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: f.title)
        .accessibilityElement(children: .contain)
    }

    /// «Firenze · Settore B · Attiva fino alle 20:00»
    static func zoneLine(_ check: PlaceCheck) -> String? {
        let parts = [check.city?.localizedName, check.pedestrian?.name ?? check.zone?.shortName, check.until].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var waiting: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Waiting for your position…")).font(Theme.display(30, .bold)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if monitor.locationDenied {
                bigButton(L("Open Settings"), "gearshape.fill") { LocationGate.openSettings() }
            } else if monitor.location == nil {
                bigButton(L("Use my location"), "location.fill") { monitor.askLocation(store: store) }
            } else if monitor.approximate {
                Text(L("Approximate location: search the address instead.")).font(.app(size: 20)).foregroundStyle(Theme.muted)
            }
        }
    }

    private func bigButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(Theme.display(22, .bold)).foregroundStyle(Theme.onPrimary)
                .frame(maxWidth: .infinity, minHeight: Theme.Target.car)
                .background(Theme.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
