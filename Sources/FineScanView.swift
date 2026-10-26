import SwiftUI
import UIKit

/// «Fotografa il verbale»: legge data, ora, varco e Comune, confronta con gli orari che conosciamo,
/// calcola le scadenze dalla notifica e prepara una bozza di ricorso. Informazioni generali, non legali.
struct FineScanView: View {
    @EnvironmentObject var store: Store
    @State private var text = ""
    @State private var notice = FineReader.Notice()
    @State private var scanned = false
    @State private var violation = Date()
    @State private var hasViolation = false
    @State private var place = ""
    @State private var cityId: String?
    @State private var zoneId: String?
    @State private var notified = Date()
    @State private var copied = false

    private var city: City? { store.cities.first { $0.id == cityId } }
    private var zone: Zone? { city?.zones.first { $0.id == zoneId } }
    private var engine: RuleEngine { store.engine }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Photograph the first page of the notice (verbale). GateLR reads date, time, gate and amounts on this iPhone: nothing is sent.")
                        .font(.app(size: 15)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    DocumentCapture(languages: ["it-IT", "en-US"], correction: true) { found in
                        text = found
                        readText()
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Text on the notice")
                    TextField(L("Or type the main lines of the notice"), text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(12)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("fine.text")
                    if !text.isEmpty {
                        Button { readText() } label: { Label("Read this text", systemImage: "text.viewfinder") }
                            .font(.app(size: 15, weight: .semibold)).tint(Theme.blue)
                    }
                }
                .padding(14).card()
                if scanned {
                    details
                    verdict
                    deadlines
                    appeal
                }
                references
                Text("General information, not legal advice: we are not lawyers. The notice you received and the official texts always win.")
                    .font(.app(size: 12)).foregroundStyle(Theme.muted)
            }
            .padding(20)
        }
        .background(Theme.ground)
        .navigationTitle("Photograph the notice")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.blue)
    }

    private func readText() {
        let n = FineReader.parse(text)
        notice = n
        scanned = true
        copied = false
        hasViolation = n.violation != nil
        if let v = n.violation { violation = v }
        place = n.place ?? ""
        if let d = n.notificationDate { notified = d }
        let m = FineCheck.match(n, text: text, cities: store.cities)
        cityId = m?.city.id
        zoneId = m?.zone?.id
    }

    /// Cambiato il luogo o la città: si cerca di nuovo il varco
    private func rematch() {
        guard let c = city else { zoneId = nil; return }
        var n = notice
        n.place = place
        if let found = FineCheck.gate(place, in: c) { zoneId = found.zone.id }
        else if !c.zones.contains(where: { $0.id == zoneId }) { zoneId = FineCheck.zone(for: n, text: text, in: c)?.id }
    }

    // MARK: Quello che abbiamo letto

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("What we read")
            if !notice.understood {
                Label("I can't find the details of a ZTL fine in this text. Try a sharper photo of the first page, or fill in the fields.", systemImage: "questionmark.circle")
                    .font(.app(size: 14)).foregroundStyle(Theme.amberInk)
            }
            if hasViolation {
                DatePicker(L("Violation"), selection: $violation)
                    .environment(\.timeZone, engine.calendar.timeZone)
                    .font(.app(size: 15))
                if !notice.violationHasTime {
                    Text("Time not found: set it as written on the notice.").font(.app(size: 13)).foregroundStyle(Theme.amberInk)
                }
            } else {
                Button { hasViolation = true } label: { Label("Add the date and time of the violation", systemImage: "calendar.badge.plus") }
                    .font(.app(size: 15, weight: .semibold))
            }
            HStack {
                Text("Gate or street").font(.app(size: 15))
                Spacer()
                TextField(L("e.g. Via Cavour"), text: $place)
                    .multilineTextAlignment(.trailing).font(.app(size: 15, weight: .semibold))
                    .onSubmit { rematch() }
            }
            Picker(L("City"), selection: $cityId) {
                Text("–").tag(String?.none)
                ForEach(store.cities) { Text($0.localizedName).tag(Optional($0.id)) }
            }
            .onChange(of: cityId) { rematch() }
            if let c = city {
                Picker(L("Zone"), selection: $zoneId) {
                    Text("–").tag(String?.none)
                    ForEach(c.zones) { Text($0.localizedName).tag(Optional($0.id)) }
                }
            }
            if let a = notice.amount { info(L("Amount"), a.formatted(.currency(code: "EUR"))) }
            if let r = notice.reducedAmount { info(L("Within 5 days"), r.formatted(.currency(code: "EUR"))) }
            if let a = notice.articleText { info(L("Article"), a) }
            if let n = notice.number { info(L("Notice number"), n) }
            if let p = notice.plate { info(L("Plate"), p) }
        }
        .padding(14).card()
    }

    private func info(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.app(size: 15))
            Spacer()
            Text(value).font(.app(size: 15, weight: .semibold)).multilineTextAlignment(.trailing)
        }
    }

    // MARK: Il varco era attivo?

    private var status: FineCheck.Status? {
        guard hasViolation, let z = zone else { return nil }
        return FineCheck.status(z, at: violation, engine: engine)
    }

    @ViewBuilder
    private var verdict: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Was the gate active?")
            if let z = zone, let s = status {
                let look = Self.look(s)
                Label(look.title, systemImage: look.symbol)
                    .font(.app(size: 16, weight: .bold)).foregroundStyle(look.ink)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(look.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(verbatim: z.localizedName + " · " + engine.format(violation, .dateTime.weekday(.wide).day().month().year().hour().minute()))
                    .font(.app(size: 14, weight: .semibold))
                Text("These are today's hours as published by the city: on that day they may have been different (summer hours, events, panels off). We are not lawyers: check the notice and the official source.")
                    .font(.app(size: 13)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: z.source.pageURL) {
                    Label(String(format: L("Official source: %@"), z.source.localizedAuthority), systemImage: "arrow.up.right.square")
                        .font(.app(size: 14, weight: .semibold))
                }
            } else {
                Text(hasViolation ? L("Choose the city and the zone to compare with the hours we know.")
                     : L("Add the date and time of the violation to compare with the hours we know."))
                    .font(.app(size: 14)).foregroundStyle(Theme.muted)
            }
        }
        .padding(14).card()
    }

    private static func look(_ s: FineCheck.Status) -> (title: String, symbol: String, fill: Color, ink: Color) {
        switch s {
        case .active: return (L("According to the rules we know, the gate was active"), "video.fill", Theme.red, Color.white)
        case .inactive: return (L("According to the rules we know, the gate was not active"), "video.slash.fill", Theme.green, Color.white)
        case .unsure: return (L("We can't tell: it was a public holiday and we haven't confirmed the holiday rules"), "questionmark.circle.fill", Theme.amberSoft, Theme.amberInk)
        }
    }

    // MARK: Scadenze

    private var deadlines: some View {
        let d = FineCheck.deadlines(notifiedOn: notified, calendar: engine.calendar)
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Deadlines")
            DatePicker(L("Notified on"), selection: $notified, displayedComponents: .date)
                .environment(\.timeZone, engine.calendar.timeZone)
                .font(.app(size: 15))
            if notice.notificationDate == nil {
                Text("Notification date not found: set the day you received the notice (or the delivery date of the registered letter).")
                    .font(.app(size: 13)).foregroundStyle(Theme.amberInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            deadline(L("Pay with 30% off"), d.reduced)
            deadline(L("Appeal to the Giudice di Pace"), d.giudice)
            deadline(L("Pay without the discount"), d.pay)
            deadline(L("Appeal to the Prefetto"), d.prefetto)
            if hasViolation {
                let limits = FineCheck.notificationLimits(violation: violation, calendar: engine.calendar)
                Text(String(format: L("The notice must be sent within 90 days of the violation if you live in Italy (here: by %@), within 360 days if you live abroad (by %@): art. 201 of the Highway Code. With a rental car the count can start when the company passes on your details."),
                            engine.day(limits.italy, style: .abbreviated), engine.day(limits.abroad, style: .abbreviated)))
                    .font(.app(size: 13)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Days count from the notification. General information: the deadlines and instructions written on your notice always win.")
                .font(.app(size: 12)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).card()
    }

    private func deadline(_ title: String, _ date: Date) -> some View {
        let past = date < engine.calendar.startOfDay(for: Date())
        return HStack(alignment: .firstTextBaseline) {
            Text(title).font(.app(size: 15))
            Spacer()
            Text(engine.day(date, style: .abbreviated))
                .font(.app(size: 15, weight: .semibold)).monospacedDigit()
                .foregroundStyle(past ? Theme.red : Theme.ink)
                .strikethrough(past)
        }
    }

    // MARK: Ricorso

    private var draft: String {
        var n = notice
        if hasViolation { n.violation = violation; n.violationHasTime = n.violationHasTime || notice.violation != violation }
        n.place = place.isEmpty ? nil : place
        n.notificationDate = notified
        return FineCheck.appealDraft(n, city: city?.name_it ?? city?.name ?? notice.city, zone: zone.map { $0.name_it ?? $0.name },
                                     status: status, source: zone?.source.pageURL, calendar: engine.calendar)
    }

    private var appeal: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Appeal")
            Text("A draft in Italian with the details read from the notice, to complete and check. It is not legal advice.")
                .font(.app(size: 14)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            WideButton(title: copied ? "Copied" : "Copy a text for the appeal", systemImage: copied ? "checkmark" : "doc.on.doc") {
                UIPasteboard.general.string = draft
                copied = true
            }
            .accessibilityIdentifier("fine.copyAppeal")
            DisclosureGroup(L("Show the draft")) {
                Text(draft).font(.app(size: 12, design: .monospaced)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            .font(.app(size: 14))
        }
        .padding(14).card()
    }

    private var references: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Official references")
            ForEach(Array(FineCheck.references.enumerated()), id: \.offset) { _, ref in
                Link(destination: ref.1) {
                    Label(ref.0, systemImage: "book.closed").font(.app(size: 14))
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).card()
    }
}
