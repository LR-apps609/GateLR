import SwiftUI
import UIKit
import PhotosUI
import MessageUI

// «Segnala un errore» su ogni scheda di zona e sotto la risposta di Varco: cosa non va (orari, confini, varco, altro),
// una nota, una foto facoltativa e il contesto aggiunto da solo (città, zona, data e ora scelte, veicolo, versione;
// la posizione solo se spunti «Allega la posizione»). Parte con Mail (MFMailComposeViewController) verso
// AppConfig.supportEmail; senza Mail configurata, con il foglio di condivisione (testo e foto). Nessun server.

/// Il testo della segnalazione, senza viste (lo controllano i test)
struct ZoneReport: Equatable {
    enum Topic: String, CaseIterable, Identifiable {
        case hours, boundaries, gate, other
        var id: String { rawValue }
        var title: String {
            switch self {
            case .hours: L("Hours")
            case .boundaries: L("Boundaries")
            case .gate: L("Gate")
            case .other: L("Other")
            }
        }
        var symbol: String {
            switch self {
            case .hours: "clock"
            case .boundaries: "map"
            case .gate: "video.fill"
            case .other: "ellipsis.circle"
            }
        }
    }

    var topic: Topic = .hours
    var note = ""
    var cityId: String
    var cityName: String
    var zoneId: String
    var zoneName: String
    /// La data e l'ora per cui l'app ha risposto (il chip «Adesso ▾»)
    var when: Date
    var whenIsNow = true
    var vehicle: String
    var appVersion: String
    var system = ""
    var language = ""
    /// Solo con «Allega la posizione»
    var location: Coordinate? = nil
    var testZone = false

    var subject: String { "GateLR – " + L("Report an error") + " · " + cityName + " · " + zoneName }

    /// La data in ora italiana, come il motore delle regole
    static func format(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Europe/Rome")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: d) + " (Europe/Rome)"
    }

    /// Le righe del contesto: le stesse che si vedono nel modulo prima di inviare
    var context: [String] {
        // Testo tecnico in inglese, come «Segnala un bug»: chi legge la mail lo capisce in ogni lingua
        var moment = "chosen"
        if whenIsNow { moment = "now" }
        var lines = ["What: \(topic.rawValue) (\(topic.title))",
                     "City: \(cityName) (\(cityId))",
                     "Zone: \(zoneName) (\(zoneId))",
                     "Date/time: \(Self.format(when)) · \(moment)",
                     "Vehicle: \(vehicle)",
                     "App: \(appVersion)"]
        if !system.isEmpty { lines.append("iOS: \(system)") }
        if !language.isEmpty { lines.append("Lang: \(language)") }
        if let location { lines.append(String(format: "Position: %.5f, %.5f", location.lat, location.lon)) }
        if testZone { lines.append("Test zone: yes (test mode)") }
        return lines
    }

    var body: String {
        var lines = ["GateLR – " + L("Report an error"), ""]
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { lines += [text, ""] }
        lines += ["—"] + context
        return lines.joined(separator: "\n")
    }

    /// «Fiat 500 · Benzina · Euro 6» (mai la targa)
    static func vehicleLine(_ v: Vehicle) -> String {
        [v.model.isEmpty ? v.name : v.model, v.fuel.label, "Euro \(v.euro)"].joined(separator: " · ")
    }
}

/// Il pulsante «Segnala un errore» per una zona (scheda della zona e risposta di Varco)
struct ReportErrorButton: View {
    var zone: Zone
    var city: City
    /// Sul blu notte di Varco il testo chiaro
    var onDark = false
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Label("Report an error", systemImage: "exclamationmark.bubble")
                .font(.app(size: 14, weight: .semibold))
                .foregroundStyle(onDark ? Notte.muted : Theme.blue)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(L("Tell us what's wrong with the hours, boundaries or gates of this zone")))
        .accessibilityIdentifier("zone.report")
        .sheet(isPresented: $open) { ZoneReportView(zone: zone, city: city) }
    }
}

/// Il modulo
struct ZoneReportView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var zone: Zone
    var city: City
    @State private var topic: ZoneReport.Topic = .hours
    @State private var note = ""
    @State private var attachLocation = false
    @State private var photo: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var camera = false
    @State private var mail = false
    @State private var share = false
    @State private var sent = false

    private var report: ZoneReport {
        var r = ZoneReport(topic: topic, note: note, cityId: city.id, cityName: city.localizedName, zoneId: zone.id,
                           zoneName: zone.localizedName, when: store.moment(), whenIsNow: store.when == nil,
                           vehicle: ZoneReport.vehicleLine(store.vehicle), appVersion: AppConfig.appVersion,
                           system: UIDevice.current.systemVersion, language: Locale.current.identifier,
                           testZone: TestZone.isTest(zoneId: zone.id))
        if attachLocation, let here = GateMonitor.shared.location {
            r.location = Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude)
        }
        return r
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("What's wrong?"), selection: $topic) {
                        ForEach(ZoneReport.Topic.allCases) { t in Label(t.title, systemImage: t.symbol).tag(t) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .accessibilityIdentifier("report.topic")
                } header: { Text("What's wrong?") }

                Section {
                    TextField(L("e.g. the panel says 7.30–19.30, the app says 20.00"), text: $note, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityLabel(L("Note"))
                        .accessibilityIdentifier("report.note")
                } header: { Text("Note") }

                Section {
                    if let photo {
                        HStack(spacing: 12) {
                            Image(uiImage: photo).resizable().scaledToFill()
                                .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .accessibilityLabel(L("Attached photo"))
                            Spacer()
                            Button(role: .destructive) { self.photo = nil; photoItem = nil } label: {
                                Label("Remove the photo", systemImage: "trash")
                            }
                        }
                    }
                    if CameraPicker.isAvailable {
                        Button { camera = true } label: { Label("Take a photo", systemImage: "camera") }
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(L("Choose a photo"), systemImage: "photo")
                    }
                    .accessibilityIdentifier("report.photo")
                } header: { Text("Photo (optional)") } footer: {
                    Text("For example the sign at the gate with the hours.")
                }

                Section {
                    Toggle(isOn: $attachLocation) { Label("Attach my position", systemImage: "location") }
                        .accessibilityIdentifier("report.location")
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(report.context, id: \.self) { Text(verbatim: $0) }
                    }
                    .font(.app(size: 12, design: .monospaced)).foregroundStyle(Theme.muted)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(L("Information added to the report"))
                } header: { Text("Added for you") } footer: {
                    Text("No plate. Your position only if you tick «Attach my position».")
                }

                Section {
                    Button { send() } label: {
                        Group {
                            if sent {
                                Label("Thank you!", systemImage: "checkmark")
                            } else {
                                Label("Send the report", systemImage: "paperplane.fill")
                            }
                        }
                        .font(.app(size: 16, weight: .bold))
                    }
                    .accessibilityIdentifier("report.send")
                } footer: {
                    Text(String(format: L("Sent by email to %@. Without Mail, you can share it with another app."), AppConfig.supportEmail))
                }
            }
            .navigationTitle("Report an error")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.blue)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { photo = image }
                }
            }
            .fullScreenCover(isPresented: $camera) {
                CameraPicker { image in
                    if let image { photo = image }
                    camera = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $mail) {
                MailComposer(to: AppConfig.supportEmail, subject: report.subject, body: report.body, photo: photo?.reportJPEG) { done in
                    mail = false
                    if done { sent = true; Task { try? await Task.sleep(for: .milliseconds(700)); dismiss() } }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $share) {
                ShareSheet(items: shareItems)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    /// Per il foglio di condivisione: il testo (con l'oggetto in cima) e la foto, se c'è
    private var shareItems: [Any] {
        var items: [Any] = [report.subject + "\n\n" + report.body]
        if let photo { items.append(photo) }
        return items
    }

    private func send() {
        if MFMailComposeViewController.canSendMail() { mail = true } else { share = true }
    }
}

private extension UIImage {
    /// La foto più piccola per la mail (lato lungo 1600 px)
    var reportJPEG: Data? {
        let long = max(size.width, size.height)
        guard long > 1600 else { return jpegData(compressionQuality: 0.8) }
        let k = 1600 / long
        let s = CGSize(width: size.width * k, height: size.height * k)
        return UIGraphicsImageRenderer(size: s).image { _ in draw(in: CGRect(origin: .zero, size: s)) }.jpegData(compressionQuality: 0.8)
    }
}

/// Il compositore di Mail di iOS
struct MailComposer: UIViewControllerRepresentable {
    var to: String
    var subject: String
    var body: String
    var photo: Data?
    var done: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let c = MFMailComposeViewController()
        c.mailComposeDelegate = context.coordinator
        c.setToRecipients([to])
        c.setSubject(subject)
        c.setMessageBody(body, isHTML: false)
        if let photo { c.addAttachmentData(photo, mimeType: "image/jpeg", fileName: "gatelr-segnalazione.jpg") }
        return c
    }
    func updateUIViewController(_ c: MFMailComposeViewController, context: Context) { context.coordinator.done = done }
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var done: (Bool) -> Void
        init(done: @escaping (Bool) -> Void) { self.done = done }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            done(result == .sent || result == .saved)
        }
    }
}

/// Il foglio di condivisione di iOS (testo e foto), quando Mail non è configurata
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ c: UIActivityViewController, context: Context) {}
}
