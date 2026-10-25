import SwiftUI

/// Il diario dei passaggi: quando sei passato vicino o dentro una ZTL che a quell'ora non ti faceva entrare.
/// Serve a sapere subito se può arrivare una multa (che arriva mesi dopo) e come prova in caso di ricorso.
struct DriveLogView: View {
    @EnvironmentObject var store: Store
    @State private var confirmClear = false

    private var shareText: String {
        store.log.map { e -> String in
            let when: String = e.date.formatted(date: .abbreviated, time: .shortened)
            let parts: [String?] = [when, e.zoneName, e.gateName, e.verdict, e.plate.isEmpty ? nil : e.plate]
            return parts.compactMap { $0 }.joined(separator: " · ")
        }.joined(separator: "\n")
    }

    var body: some View {
        List {
            Section {
                Text("GateLR writes here when you pass close to an active gate or drive into a zone you can't enter. Only on this iPhone.")
                    .font(.app(size: 14)).foregroundStyle(Theme.muted)
            }
            if store.log.isEmpty {
                Section { Label("Nothing yet: no active gate on your way.", systemImage: "checkmark.circle").foregroundStyle(Theme.greenInk) }
            } else {
                Section {
                    ForEach(store.log) { e in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: e.kind == .entered ? "exclamationmark.triangle.fill" : "video.fill")
                                .foregroundStyle(e.kind == .entered ? Theme.red : Theme.amberInk)   // amberInk: leggibile anche in modalità scura
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.zoneName).font(.app(size: 15, weight: .semibold))
                                Text([e.date.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()),
                                      e.gateName, e.plate.isEmpty ? nil : e.plate].compactMap { $0 }.joined(separator: " · "))
                                    .font(.app(size: 13)).foregroundStyle(Theme.muted)
                                Text(e.kind == .entered ? L("Drove into the zone") + " · " + e.verdict : L("Near an active gate") + " · " + e.verdict)
                                    .font(.app(size: 13, weight: .medium))
                                    .foregroundStyle(e.kind == .entered ? Theme.red : Theme.amberInk)
                            }
                        }
                    }
                    .onDelete { store.log.remove(atOffsets: $0) }
                } footer: {
                    Text("A row here doesn't mean you'll be fined: maybe you didn't cross the gate, or your plate was registered. It's a reminder, and a note of when and where.")
                }
                Section {
                    ShareLink(item: shareText) {
                        Label("Share the log", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { confirmClear = true } label: { Label("Delete the log", systemImage: "trash") }
                }
            }
        }
        .navigationTitle("Drive log")
        .tint(Theme.blue)
        .confirmationDialog(L("Delete the whole log?"), isPresented: $confirmClear) {
            Button(L("Delete the log"), role: .destructive) { store.log = [] }
        }
    }
}

/// «Ho preso una multa?»: cosa succede, quanto costa, come pagare dall'estero, come fare ricorso
struct FineGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                step("1", "When it arrives", "In Italy the notice must arrive within 90 days. If you live abroad it can take up to a year (360 days). With a rental car, the company is asked first and then passes on your details.")
                step("2", "The rental company's charge", "The rental company often charges your card €30–90 for passing on your details. That's their fee, not the fine: the fine arrives later, by post, from the city.")
                step("3", "How much", fineText)
                step("4", "How to pay", "The notice has the amount, the deadline and the payment details (often an IBAN for a bank transfer; some cities also take cards online through pagoPA). Foreign cards are sometimes refused: a bank transfer always works. Keep the receipt and write the notice number in the payment reference.")
                step("5", "Disagree? Appeal", "Within 60 days to the Prefetto, or within 30 days to the Giudice di Pace (justice of the peace), as written on the notice. Common reasons: the electronic panel was off or broken, the sign had no hours, the panel still said \"Varco attivo\", your hotel had registered your plate, or several fines for the same zone on the same day.")
                step("6", "What to keep", "The hotel's written confirmation, photos of the signs and panels, your rental contract, and GateLR's drive log with dates and places.")
                step("7", "Don't ignore it", "Unpaid fines grow after 60 days and can be sent to a collection agency, also abroad.")
                Text("General information, not legal advice. The notice you receive always wins: read its deadlines and amounts.")
                    .font(.app(size: 12)).foregroundStyle(Theme.muted)
            }
            .padding(20)
        }
        .background(Theme.ground)
        .navigationTitle("Got a fine?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var fineText: String {
        guard let f = FineInfo.bundled else { return "" }
        return String(format: L("From €%lld to €%lld per entry (in some cities once a day per zone). About 30%% off if you pay within 5 days of the notice; after 60 days it goes up."), f.min, f.max)
    }

    private func step(_ n: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(n).font(Theme.display(20)).foregroundStyle(.white)
                .frame(width: 36, height: 36).background(Theme.red, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(L(title)).font(Theme.display(21)).foregroundStyle(Theme.ink)
                Text(L(text)).font(.app(size: 15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(18)
    }
}
