import SwiftUI

/// La scheda della zona: riassunto, orari, la frase del Comune, la fonte e la data del controllo.
struct ZoneDetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var zone: Zone
    var city: City

    var body: some View {
        let answer = store.answer(zone: zone)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(zone.name).font(Theme.display(30))
                    HStack(spacing: 8) {
                        Pill(text: answer.gatesOn ? "Gates on" : "Gates off · you can enter",
                             fill: answer.gatesOn ? Theme.amberSoft : Theme.greenSoft,
                             ink: answer.gatesOn ? Theme.amberInk : Theme.greenInk)
                        Text(city.name).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                    StatusBanner(status: city.status)
                }

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel("In short")
                    Text(zone.summary).font(.system(size: 15))
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(14).card()

                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("When it's on").padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
                    ForEach(Array(scheduleRows.enumerated()), id: \.offset) { i, row in
                        HStack {
                            Text(row.days)
                            Spacer()
                            Text(row.hours).fontWeight(.semibold).monospacedDigit()
                                .foregroundStyle(row.free ? Theme.greenInk : Theme.ink)
                        }
                        .font(.system(size: 15)).padding(.horizontal, 14).padding(.vertical, 9)
                        if i < scheduleRows.count - 1 { Divider().padding(.leading, 14) }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("The city's own words")
                    if let q = zone.source.quote {
                        Text("«\(q)»").italic().font(.system(size: 14)).foregroundStyle(Color(hex: 0x3D454E))
                            .environment(\.locale, Locale(identifier: "it"))
                    }
                    if let t = zone.source.quoteTranslation {
                        Text("Translation: \(t)").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                    if let act = zone.source.ordinance, zone.source.ordinanceURL == nil {
                        Text(act).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                    Link(destination: zone.source.ordinanceURL ?? zone.source.pageURL) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text(zone.source.ordinanceURL != nil ? "\(zone.source.ordinance ?? "Ordinance") · PDF" : "Read it on the city's page").fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 14)).padding(12)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Theme.blue)
                    }
                }
                .padding(14).card()

                if !zone.source.pending.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Still to check")
                        ForEach(zone.source.pending, id: \.self) { item in
                            Label(item, systemImage: "questionmark.circle").font(.system(size: 14))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14).background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Theme.amberInk)
                }

                if !zone.source.links.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel("Sources").padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
                        ForEach(zone.source.links, id: \.self) { l in
                            Link(destination: l.url) {
                                HStack { Text(l.title).multilineTextAlignment(.leading); Spacer(); Image(systemName: "arrow.up.right") }
                                    .font(.system(size: 14)).padding(.horizontal, 14).padding(.vertical, 10)
                            }
                        }
                    }
                    .card()
                }

                Label {
                    Text(zone.source.reviewedByHuman
                         ? "Checked by a person on \(zone.source.checkedOn.formatted(date: .long, time: .omitted)). Road signs on site always win over the app."
                         : "Read from official sources on \(zone.source.checkedOn.formatted(date: .long, time: .omitted)), not yet reviewed by a person. Road signs on site always win over the app.")
                } icon: {
                    Image(systemName: zone.source.reviewedByHuman ? "checkmark.circle" : "clock").foregroundStyle(zone.source.reviewedByHuman ? Theme.green : Theme.amber)
                }
                .font(.system(size: 13)).foregroundStyle(Theme.muted)
                if let license = city.license {
                    Text(license).font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
            .padding(20)
        }
        .background(Theme.ground)
        .tint(Theme.blue)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }

    private struct Row { var days: String; var hours: String; var free = false }

    /// Le fasce raggruppate per orario: «Monday – Friday 7:30 am – 8:00 pm»
    private var scheduleRows: [Row] {
        let names = Calendar(identifier: .gregorian).weekdaySymbols   // 0 = domenica
        let f = DateFormatter(); f.dateFormat = "h:mm a"; f.locale = Locale(identifier: "en_GB")
        func time(_ m: Int) -> String {
            f.string(from: Calendar.current.date(bySettingHour: m / 60 % 24, minute: m % 60, second: 0, of: Date())!).lowercased()
        }
        let order = [2, 3, 4, 5, 6, 7, 1]
        var rows: [Row] = zone.windows.map { w in
            let days = order.filter { w.weekdays.contains($0) }
            let label = days.count > 2 && days == Array(order[order.firstIndex(of: days[0])!..<order.firstIndex(of: days[0])! + days.count])
                ? "\(names[days.first! - 1]) – \(names[days.last! - 1])"
                : days.map { names[$0 - 1] }.joined(separator: ", ")
            let season = w.season.map { s in
                let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "en_GB")
                let c = Calendar(identifier: .gregorian)
                let a = c.date(from: DateComponents(year: 2026, month: s.fromMonth, day: s.fromDay))!
                let b = c.date(from: DateComponents(year: 2026, month: s.toMonth, day: s.toDay))!
                return " (\(f.string(from: a)) – \(f.string(from: b)))"
            } ?? ""
            return Row(days: label + season, hours: "\(time(w.start)) – \(time(w.end))")
        }
        let covered = Set(zone.windows.filter { $0.season == nil }.flatMap(\.weekdays))
        let free = order.filter { !covered.contains($0) }.map { names[$0 - 1] }
        let holidays = zone.freeOnHolidays == true ? ["holidays"] : []
        if !free.isEmpty || !holidays.isEmpty {
            rows.append(Row(days: (free + holidays).joined(separator: ", ").capitalizedFirst, hours: "open to all", free: true))
        }
        if zone.freeOnHolidays == nil {
            rows.append(Row(days: "Public holidays", hours: "not confirmed"))
        }
        return rows
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
