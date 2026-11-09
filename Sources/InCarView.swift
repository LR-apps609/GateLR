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
                        Label(L("Park outside"), systemImage: "figure.walk")
                            .font(Notte.fixed(24, .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .background(Notte.action, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("incar.park")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(glow(subject).ignoresSafeArea())
        }
        .environment(\.colorScheme, .dark)
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
                .font(Notte.fixed(15, .bold)).kerning(1.4).foregroundStyle(Notte.muted)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 22, weight: .bold)).foregroundStyle(Notte.text)
                    .frame(width: 60, height: 60)
                    .background(Notte.surface, in: Circle())
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

    private func answer(_ s: Adesso.Subject) -> some View {
        let f = s.check.finale
        return VStack(alignment: .leading, spacing: 14) {
            // Forma + parola + colore, mai solo colore
            Image(systemName: f.symbol)
                .font(.system(size: 34, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(f.stato.tint, in: Circle())
                .overlay { if f.stato.dashed { Circle().stroke(style: StrokeStyle(lineWidth: 3, dash: [6, 5])).foregroundStyle(Notte.text) } }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: -8) {
                ForEach(f.word.lines.map { $0.uppercased() }, id: \.self) { line in
                    Text(verbatim: line).font(Notte.fixed(64, .black)).foregroundStyle(Notte.text)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(f.spoken)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("incar.answer")
            if let m = s.aheadMeters {
                Text(verbatim: Adesso.aheadLine(m))
                    .font(Notte.fixed(40, .bold)).foregroundStyle(Notte.text)
                    .lineLimit(2).minimumScaleFactor(0.6)
            }
            Text(verbatim: VarcoView.placeTitle(s.check))
                .font(Notte.fixed(26, .semibold)).foregroundStyle(Notte.text)
                .lineLimit(2).minimumScaleFactor(0.7)
            if let line = Self.zoneLine(s.check) {
                Text(verbatim: line).font(Notte.fixed(20, .semibold)).foregroundStyle(Notte.muted)
                    .lineLimit(2).minimumScaleFactor(0.7)
            }
            if let reason = f.reasonLine {
                Text(verbatim: reason).font(Notte.fixed(20, .semibold)).foregroundStyle(Notte.muted)
            }
        }
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
            Text(L("Waiting for your position…")).font(Notte.fixed(30, .bold)).foregroundStyle(Notte.text)
                .fixedSize(horizontal: false, vertical: true)
            if monitor.locationDenied {
                bigButton(L("Open Settings"), "gearshape.fill") { LocationGate.openSettings() }
            } else if monitor.location == nil {
                bigButton(L("Use my location"), "location.fill") { monitor.askLocation(store: store) }
            } else if monitor.approximate {
                Text(L("Approximate location: search the address instead.")).font(Notte.fixed(20)).foregroundStyle(Notte.muted)
            }
        }
    }

    private func bigButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(Notte.fixed(22, .bold)).foregroundStyle(Notte.navy)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Notte.text, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func glow(_ s: Adesso.Subject?) -> some View {
        ZStack {
            Notte.navy
            if let s {
                RadialGradient(colors: [s.check.finale.stato.tint.opacity(0.35), .clear], center: .top, startRadius: 10, endRadius: 520)
            }
        }
    }
}
