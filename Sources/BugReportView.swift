import SwiftUI
import UIKit

/// «Segnala un bug»: si scrive cosa è successo, l'app aggiunge le informazioni tecniche
/// (versione, iPhone, lingua, città e zona scelte) e si invia con Mail, Messaggi o altro.
struct BugReportView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var screen: Screen = .varco
    @State private var withInfo = true
    @State private var copied = false

    /// L'indirizzo a cui arrivano le segnalazioni: da decidere prima della pubblicazione.
    /// Finché è nil, la segnalazione si condivide (Mail, Messaggi, WhatsApp…) o si copia.
    static let supportEmail: String? = nil

    enum Screen: String, CaseIterable, Identifiable {
        case varco, map, trip, garage, account, widget, alerts, other
        var id: String { rawValue }
        var title: String {
            switch self {
            case .varco: L("Gate")
            case .map: L("Map")
            case .trip: L("Trip")
            case .garage: L("Garage")
            case .account: L("Account")
            case .widget: L("Widget")
            case .alerts: L("Gate alerts")
            case .other: L("Other")
            }
        }
    }

    private var report: String {
        var lines = ["GateLR – " + L("Bug report"), "", text.trimmingCharacters(in: .whitespacesAndNewlines), "",
                     L("Where") + ": " + screen.title]
        if withInfo {
            let info = Bundle.main.infoDictionary
            lines += ["",
                      "App: \(info?["CFBundleShortVersionString"] as? String ?? "–") (\(info?["CFBundleVersion"] as? String ?? "–"))",
                      "iOS: \(UIDevice.current.systemVersion) · \(Self.model)",
                      "Lang: \(Locale.current.identifier)",
                      "City/zone: \(store.city.id) / \(store.zone.id)",
                      "Date: \(Date().formatted(.iso8601))"]
        }
        return lines.joined(separator: "\n")
    }

    /// Il modello dell'iPhone, es. «iPhone16,2»
    private static var model: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("What happened? What did you expect?")
                                    .foregroundStyle(Theme.muted).padding(.top, 8).padding(.leading, 4).allowsHitTesting(false)
                            }
                        }
                } header: { Text("Describe the problem") }
                Section {
                    Picker(L("Where"), selection: $screen) { ForEach(Screen.allCases) { Text($0.title).tag($0) } }
                    Toggle(L("Add technical info"), isOn: $withInfo)
                } footer: {
                    Text("Technical info: app version, iOS, iPhone model, language and the chosen zone. No location, no plate.")
                }
                Section {
                    if let email = Self.supportEmail, let url = mailURL(email) {
                        Link(destination: url) { Label("Send by email", systemImage: "envelope") }
                    }
                    ShareLink(item: report) { Label("Send", systemImage: "paperplane") }
                    Button {
                        UIPasteboard.general.string = report
                        copied = true
                    } label: { Label(copied ? L("Copied") : L("Copy"), systemImage: copied ? "checkmark" : "doc.on.doc") }
                    .sensoryFeedback(.success, trigger: copied) { _, new in new }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Report a bug")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.blue)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func mailURL(_ email: String) -> URL? {
        var c = URLComponents(string: "mailto:\(email)")
        c?.queryItems = [URLQueryItem(name: "subject", value: "GateLR – " + L("Bug report")), URLQueryItem(name: "body", value: report)]
        return c?.url
    }
}
