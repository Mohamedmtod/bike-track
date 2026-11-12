import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit

/// SwiftUI Live Activity widget for Gym Rest Timer on iOS 16.1+.
/// Displays Dynamic Island layouts (Compact, Expanded, Minimal) and Lock Screen banner on iPhone 14 Pro.
@available(iOS 16.1, *)
public struct GymRestLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymRestAttributes.self) { context in
            // Lock Screen & StandBy Mode Banner View
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.80, green: 1.0, blue: 0.0)) // ProBike Lime
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.state.exerciseName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("Set \(context.state.setNumber) Completed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.55, green: 0.60, blue: 0.68))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("REST TIMER")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Color(red: 0.80, green: 1.0, blue: 0.0))
                    Text(timerInterval: Date()...context.state.restEndTime, countsDown: true)
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(red: 0.06, green: 0.07, blue: 0.10)) // ProBike Titanium Dark
            .activityBackgroundTint(Color(red: 0.06, green: 0.07, blue: 0.10))
            .activitySystemActionForegroundColor(Color(red: 0.80, green: 1.0, blue: 0.0))

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island View (when user long-presses the pill)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.80, green: 1.0, blue: 0.0))
                        Text(context.state.exerciseName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.leading, 6)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.restEndTime, countsDown: true)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(red: 0.80, green: 1.0, blue: 0.0))
                        .padding(.trailing, 6)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Set \(context.state.setNumber)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.55, green: 0.60, blue: 0.68))
                        Spacer()
                        Text("ProBike Rest")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 0.40, green: 0.45, blue: 0.52))
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact Leading (Left of camera cutout)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.80, green: 1.0, blue: 0.0))
                    .padding(.leading, 2)
            } compactTrailing: {
                // Compact Trailing (Right of camera cutout)
                Text(timerInterval: Date()...context.state.restEndTime, countsDown: true)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.80, green: 1.0, blue: 0.0))
                    .frame(width: 44)
            } minimal: {
                // Minimal (When multiple apps share the Dynamic Island)
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.80, green: 1.0, blue: 0.0))
            }
        }
    }
}
#endif
