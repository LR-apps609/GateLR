import WidgetKit
import SwiftUI
import ActivityKit

/// La guida sulla schermata di blocco e nella Dynamic Island: prossima manovra, distanza, avviso ZTL
struct DriveLiveActivity: Widget {
    private static let blue = Color(hex: 0x1F4E9E)
    private static let red = Color(hex: 0xC1272D)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: context.state.symbol).font(.system(size: 30, weight: .bold))
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.state.distance).font(.system(size: 24, weight: .bold)).monospacedDigit()
                        Text(context.state.instruction).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if let eta = context.state.eta {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(eta, style: .time).font(.system(size: 17, weight: .bold)).monospacedDigit()
                            Text(context.attributes.destination).font(.system(size: 12)).lineLimit(1).opacity(0.85)
                        }
                    }
                }
                if let w = context.state.warning {
                    Label(w, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Self.red, in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .activityBackgroundTint(Self.blue)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.symbol).font(.system(size: 28, weight: .bold)).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.distance).font(.system(size: 22, weight: .bold)).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.instruction).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                        if let w = context.state.warning {
                            Label(w, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(Self.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.warning == nil ? context.state.symbol : "exclamationmark.triangle.fill")
                    .foregroundStyle(context.state.warning == nil ? .white : Self.red)
            } compactTrailing: {
                Text(context.state.distance).font(.system(size: 13, weight: .semibold)).monospacedDigit()
            } minimal: {
                Image(systemName: context.state.warning == nil ? context.state.symbol : "exclamationmark.triangle.fill")
            }
            .widgetURL(URL(string: "gatelr://varco"))
        }
    }
}
