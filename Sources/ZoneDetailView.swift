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
                    if city.isSample { SampleBanner() }
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
                    Link(destination: zone.source.ordinanceURL ?? zone.source.pageURL) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text(zone.source.ordinance.map { "\($0) · PDF" } ?? "Official page").fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 14)).padding(12)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Theme.blue)
                    }
                }
                .padding(14).card()

                Label {
                    Text("Checked by a person on \(zone.source.checkedOn.formatted(date: .long, time: .omitted)). Road signs on site always win over the app.")
                } icon: {
                    Image(systemName: "checkmark.circle").foregroundStyle(Theme.green)
                }
                .font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            .padding(20)
        }
        .background(Theme.ground)
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
            return Row(days: label, hours: "\(time(w.start)) – \(time(w.end))")
        }
        let covered = Set(zone.windows.flatMap(\.weekdays))
        let free = order.filter { !covered.contains($0) }.map { names[$0 - 1] }
        if !free.isEmpty || zone.freeOnHolidays {
            rows.append(Row(days: (free + (zone.freeOnHolidays ? ["holidays"] : [])).joined(separator: ", ").capitalizedFirst,
                            hours: "open to all", free: true))
        }
        return rows
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
