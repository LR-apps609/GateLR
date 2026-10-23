import SwiftUI
import UIKit

/// «Viaggio»: la risposta per il momento dell'arrivo, e il messaggio pronto per l'hotel.
struct TripView: View {
    @EnvironmentObject var store: Store
    @State private var arrival = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date().addingTimeInterval(86_400 * 3))!
    @State private var hotelName = ""
    @State private var language: MessageLanguage = .en

    var body: some View {
        let answer = store.answer(at: arrival)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 0) {
                        DatePicker(selection: $arrival, in: Date()...) {
                            Label("Arrival", systemImage: "calendar").foregroundStyle(Theme.blue)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        Divider().padding(.leading, 14)
                        HStack {
                            Image(systemName: "house").foregroundStyle(Theme.blue)
                            TextField("Hotel name", text: $hotelName)
                        }
                        .padding(14)
                        Divider().padding(.leading, 14)
                        Toggle("Hotel is inside the ZTL", isOn: $store.hotelInside).padding(.horizontal, 14).padding(.vertical, 8)
                    }
                    .card()

                    VerdictCard(answer: answer,
                                heading: arrival.formatted(.dateTime.weekday(.wide).day().month().hour().minute()),
                                source: store.zone.source)

                    if store.hotelInside && store.zone.hotelCanRegister { hotelMessage }

                    HStack {
                        Image(systemName: "bell").foregroundStyle(Theme.red)
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

    private var hotelMessage: some View {
        let text = language.message(arrival: arrival, plate: store.vehicle.plate.isEmpty ? "[PLATE]" : store.vehicle.plate)
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
                .background(Theme.ground, in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 10) {
                ShareLink(item: text) {
                    Text("Send to hotel").frame(maxWidth: .infinity, minHeight: 46)
                        .background(Theme.blue, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
                }
                Button { UIPasteboard.general.string = text } label: {
                    Text("Copy").frame(maxWidth: .infinity, minHeight: 46)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Theme.blue)
                }
            }
            .font(.system(size: 15, weight: .semibold))
        }
        .padding(14).card()
    }
}

enum MessageLanguage: String, CaseIterable, Identifiable {
    case it, en, de
    var id: String { rawValue }

    func message(arrival: Date, plate: String) -> String {
        let locale = Locale(identifier: rawValue)
        let day = arrival.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
        let time = arrival.formatted(.dateTime.hour().minute().locale(locale))
        switch self {
        case .en: return "Hello, I'm arriving by car on \(day) at about \(time). Could you please register my plate \(plate) for the ZTL? Thank you!"
        case .it: return "Buongiorno, arrivo in auto \(day) verso le \(time). Potete registrare la mia targa \(plate) per la ZTL? Grazie!"
        case .de: return "Guten Tag, ich komme am \(day) gegen \(time) mit dem Auto an. Könnten Sie bitte mein Kennzeichen \(plate) für die ZTL anmelden? Vielen Dank!"
        }
    }
}
