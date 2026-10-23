import SwiftUI
import UIKit

/// «Viaggio»: la risposta per il momento dell'arrivo, e il messaggio pronto per l'hotel.
struct TripView: View {
    @EnvironmentObject var store: Store
    @Binding var showZone: Bool
    @State private var arrival = TripView.at(dayOffset: 3, hour: 18)
    @AppStorage("hotelName") private var hotelName = ""
    @State private var language: MessageLanguage = .en
    @State private var copied = false

    var body: some View {
        let answer = store.answer(at: arrival)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        DatePicker(selection: $arrival, in: Date()...) {
                            Label("Arrival", systemImage: "calendar").foregroundStyle(Theme.blue)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                chip("Tonight 9 pm", TripView.at(dayOffset: 0, hour: 21))
                                chip("Tomorrow 10 am", TripView.at(dayOffset: 1, hour: 10))
                                chip("Saturday 6 pm", TripView.next(weekday: 7, hour: 18))
                                chip("Sunday noon", TripView.next(weekday: 1, hour: 12))
                            }
                            .padding(.horizontal, 14).padding(.bottom, 10)
                        }
                        Divider().padding(.leading, 14)
                        HStack {
                            Image(systemName: "building.2").foregroundStyle(Theme.blue)
                            TextField("Hotel name (optional)", text: $hotelName)
                                .textInputAutocapitalization(.words)
                        }
                        .padding(14)
                        Divider().padding(.leading, 14)
                        Toggle("Hotel is inside the ZTL", isOn: $store.hotelInside).padding(.horizontal, 14).padding(.vertical, 8)
                        if store.hotelInside {
                            Divider().padding(.leading, 14)
                            Picker("Sector", selection: $store.zoneId) {
                                ForEach(store.city.zones) { Text($0.name).tag($0.id) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 4)
                        }
                    }
                    .card()

                    VerdictCard(answer: answer,
                                heading: arrival.formatted(.dateTime.weekday(.wide).day().month().hour().minute()),
                                source: store.zone.source,
                                onWhy: { showZone = true })

                    if store.hotelInside && store.zone.hotelCanRegister { hotelMessage }

                    HStack {
                        Image(systemName: "bell.badge").foregroundStyle(Theme.red)
                        Toggle("Warn me \(Int(store.alertDistance)) m before a gate", isOn: $store.alertsOn)
                    }
                    .font(.system(size: 14)).padding(.horizontal, 14).padding(.vertical, 8).card()
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .background(Theme.ground)
            .navigationTitle("Your arrival")
        }
    }

    private func chip(_ title: String, _ date: Date) -> some View {
        let on = abs(arrival.timeIntervalSince(date)) < 60
        return Button { withAnimation(.snappy) { arrival = date } } label: {
            Text(title).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12).frame(height: 32)
                .background(on ? Color(hex: 0x1F4E9E) : Theme.blueSoft, in: Capsule())
                .foregroundStyle(on ? .white : Theme.blue)
        }
        .buttonStyle(.plain)
    }

    private var hotelMessage: some View {
        let text = language.message(arrival: arrival,
                                    plate: store.vehicle.plate.isEmpty ? "[PLATE]" : store.vehicle.plate,
                                    hotel: hotelName.isEmpty ? nil : hotelName)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Message for the hotel")
                Spacer()
                Picker("Message language", selection: $language) {
                    ForEach(MessageLanguage.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 140)
            }
            Text(text).font(.system(size: 14)).padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .textSelection(.enabled)
            if store.vehicle.plate.isEmpty {
                Label("Add your plate in Garage to fill it in.", systemImage: "info.circle")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 10) {
                ShareLink(item: text) {
                    Label("Send to hotel", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color(hex: 0x1F4E9E), in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(.white)
                }
                Button {
                    UIPasteboard.general.string = text
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(Theme.blue)
                }
                .sensoryFeedback(.success, trigger: copied) { _, new in new }
            }
            .font(.system(size: 15, weight: .semibold))
        }
        .padding(14).card()
    }

    static func at(dayOffset: Int, hour: Int) -> Date {
        let c = Calendar.current
        let day = c.date(byAdding: .day, value: dayOffset, to: Date())!
        return c.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    static func next(weekday: Int, hour: Int) -> Date {
        let c = Calendar.current
        let comps = DateComponents(hour: hour, minute: 0, second: 0, weekday: weekday)
        return c.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime) ?? Date()
    }
}

enum MessageLanguage: String, CaseIterable, Identifiable {
    case it, en, de
    var id: String { rawValue }

    func message(arrival: Date, plate: String, hotel: String? = nil) -> String {
        let locale = Locale(identifier: rawValue)
        let day = arrival.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
        let time = arrival.formatted(.dateTime.hour().minute().locale(locale))
        switch self {
        case .en:
            let to = hotel.map { "Dear \($0) team,\n\n" } ?? "Hello,\n\n"
            return "\(to)I'm arriving by car on \(day) at about \(time). Could you please register my plate \(plate) for the ZTL, so I can reach the hotel without a fine?\n\nThank you!"
        case .it:
            let to = hotel.map { "Gentile staff di \($0),\n\n" } ?? "Buongiorno,\n\n"
            return "\(to)arrivo in auto \(day) verso le \(time). Potete registrare la mia targa \(plate) per la ZTL, così raggiungo l'hotel senza multa?\n\nGrazie!"
        case .de:
            let to = hotel.map { "Liebes Team von \($0),\n\n" } ?? "Guten Tag,\n\n"
            return "\(to)ich komme am \(day) gegen \(time) mit dem Auto an. Könnten Sie bitte mein Kennzeichen \(plate) für die ZTL anmelden, damit ich das Hotel ohne Bußgeld erreiche?\n\nVielen Dank!"
        }
    }
}
