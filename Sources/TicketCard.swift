import SwiftUI
import UserNotifications

/// Il ticket delle ZTL a pagamento (Milano Area C, Bologna): prezzo, entro quando attivarlo, link per pagare
/// e un promemoria, perché chi lo dimentica prende la multa anche se voleva pagare.
struct TicketCard: View {
    var zone: Zone
    var ticket: Ticket
    var entry: Date
    @State private var reminded = false

    /// Entro quando va attivato per un ingresso a quell'ora
    var deadline: Date {
        let c = Calendar.current
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
                     ? String(format: L("Activate it by %@."), deadline.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))
                     : L("Buy and activate it before you drive in.")).font(.system(size: 15, weight: .semibold))
            } icon: { Image(systemName: "clock.badge.exclamationmark").foregroundStyle(Theme.amber) }
            Text(ticket.localizedHowTo).font(.system(size: 14)).foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                if let url = ticket.url {
                    Link(destination: url) {
                        Label("Pay the ticket", systemImage: "creditcard")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Theme.blueFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                }
                Button { remind() } label: {
                    Label(reminded ? L("Reminder set") : L("Remind me"), systemImage: reminded ? "checkmark" : "bell")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Theme.blue)
                }
                .disabled(reminded)
                .sensoryFeedback(.success, trigger: reminded) { _, new in new }
            }
        }
        .padding(14).card()
    }

    /// Area C: la sera dell'ingresso alle 20. Bologna: un'ora prima di entrare.
    private func remind() {
        let when = ticket.deadline == "nextDayMidnight"
            ? (Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: entry) ?? entry)
            : entry.addingTimeInterval(-3600)
        let content = UNMutableNotificationContent()
        content.title = String(format: L("%@: ticket"), zone.shortName)
        content.body = ticket.deadline == "nextDayMidnight"
            ? String(format: L("Have you activated the ticket? Deadline: %@."), deadline.formatted(.dateTime.weekday(.wide).hour().minute()))
            : L("Buy and activate the ticket before you drive in.")
        content.sound = .default
        let trigger: UNNotificationTrigger = when > Date().addingTimeInterval(60)
            ? UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: when), repeats: false)
            : UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "ticket|\(zone.id)", content: content, trigger: trigger))
            reminded = true
        }
    }
}
