import SwiftUI
import UserNotifications

/// Il ticket delle ZTL a pagamento (Milano Area C, Bologna): prezzo, entro quando attivarlo, link per pagare
/// e un promemoria, perché chi lo dimentica prende la multa anche se voleva pagare.
struct TicketCard: View {
    var zone: Zone
    var ticket: Ticket
    var entry: Date
    /// nil = non ancora; false = le notifiche sono spente (2.0, B70: prima «Promemoria impostato» anche senza notifiche)
    @State private var reminded: Bool?

    /// Entro quando va attivato per un ingresso a quell'ora
    var deadline: Date {
        // «Entro la mezzanotte del giorno dopo» è la mezzanotte di Milano, non quella del fuso del telefono
        let c = RuleEngine().calendar
        switch ticket.deadline {
        case "nextDayMidnight":
            let nextDay = c.date(byAdding: .day, value: 1, to: c.startOfDay(for: entry)) ?? entry
            return c.date(bySettingHour: 23, minute: 59, second: 0, of: nextDay) ?? nextDay
        default:
            return entry
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Day ticket")
                Spacer()
                Text(ticket.priceText).font(Theme.display(24)).foregroundStyle(Theme.blue).monospacedDigit()
            }
            Label {
                Text(ticket.deadline == "nextDayMidnight"
                     ? String(format: L("Activate it by %@."), RuleEngine.format(deadline, .dateTime.weekday(.wide).day().month().hour().minute()))
                     : L("Buy and activate it before you drive in.")).font(.app(size: 15, weight: .semibold))
            } icon: { Image(systemName: "clock.badge.exclamationmark").foregroundStyle(Theme.amberInk) }
            Text(ticket.localizedHowTo).font(.app(size: 14)).foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                if let url = ticket.url {
                    Link(destination: url) {
                        Label("Pay the ticket", systemImage: "creditcard")
                            .font(.app(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Theme.blueFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                }
                Button { if reminded == false { LocationGate.openSettings() } else { remind() } } label: {
                    Label(reminded == true ? L("Reminder set") : L("Remind me"), systemImage: reminded == true ? "checkmark" : "bell")
                        .font(.app(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Theme.blue)
                }
                .disabled(reminded == true)
                .sensoryFeedback(.success, trigger: reminded == true) { _, new in new }
            }
            if reminded == false { RemindersOffNote() }
        }
        .padding(14).card()
    }

    /// Area C: la sera dell'ingresso alle 20. Bologna: un'ora prima di entrare.
    private func remind() {
        let when = ticket.deadline == "nextDayMidnight"
            ? (RuleEngine().calendar.date(bySettingHour: 20, minute: 0, second: 0, of: entry) ?? entry)
            : entry.addingTimeInterval(-3600)
        let content = UNMutableNotificationContent()
        content.title = String(format: L("%@: ticket"), zone.shortName)
        content.body = ticket.deadline == "nextDayMidnight"
            ? String(format: L("Have you activated the ticket? Deadline: %@."), RuleEngine.format(deadline, .dateTime.weekday(.wide).hour().minute()))
            : L("Buy and activate the ticket before you drive in.")
        content.sound = .default
        let trigger: UNNotificationTrigger = when > Date().addingTimeInterval(60)
            ? UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: when), repeats: false)
            : UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        Task {
            reminded = await Reminders.add(UNNotificationRequest(identifier: "ticket|\(zone.id)", content: content, trigger: trigger))
        }
    }
}

/// 2.0 (B70): i promemoria (ticket, hotel) si dicono impostati solo se iOS li ha davvero accettati
enum Reminders {
    /// Chiede le notifiche se serve, poi aggiunge il promemoria. Falso se le notifiche sono spente o iOS lo rifiuta
    static func add(_ request: UNNotificationRequest) async -> Bool {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        guard await GateMonitor.notificationsAllowed() else { return false }
        do { try await center.add(request) } catch { return false }
        return true
    }
}

/// «Le notifiche sono spente: attivale nelle Impostazioni», con il link (2.0, B70)
struct RemindersOffNote: View {
    var body: some View {
        Button { LocationGate.openSettings() } label: {
            Label(L("Notifications are off: turn them on in Settings"), systemImage: "bell.slash")
                .font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.amberInk)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reminders.off")
    }
}
