import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Native lifecycle manager for Gym Rest Timer Live Activity on iOS 16.1+.
@available(iOS 16.1, *)
public class GymLiveActivityManager {
    public static let shared = GymLiveActivityManager()
    private var currentActivity: Any?

    private init() {}

    /// Starts a new Live Activity for the rest countdown.
    public func startRestActivity(
        durationSeconds: Int,
        endsAtUtc: String,
        exerciseName: String,
        setNumber: Int
    ) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Activities are disabled by user or system.")
            return false
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var targetDate = formatter.date(from: endsAtUtc)
        if targetDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            targetDate = formatter.date(from: endsAtUtc)
        }
        let endDate = targetDate ?? Date().addingTimeInterval(TimeInterval(durationSeconds))

        let attributes = GymRestAttributes(sessionTitle: "ProBike Rest")
        let contentState = GymRestAttributes.ContentState(
            restEndTime: endDate,
            totalSeconds: durationSeconds,
            exerciseName: exerciseName,
            setNumber: setNumber
        )

        // End any active activity cleanly before starting a new one
        endRestActivity()

        do {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(
                    state: contentState,
                    staleDate: endDate.addingTimeInterval(30)
                )
                let activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                currentActivity = activity
            } else {
                let activity = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
                currentActivity = activity
            }
            print("[LiveActivity] Successfully started activity for \(exerciseName) (Set \(setNumber))")
            return true
        } catch {
            print("[LiveActivity] Error requesting activity: \(error.localizedDescription)")
            return false
        }
    }

    /// Updates the current activity if needed.
    public func updateRestActivity(secondsRemaining: Int) {
        // Dynamic Island uses Text(timerInterval: Date()...restEndTime, countsDown: true) in SwiftUI,
        // which counts down dynamically at the OS level without per-second bridge updates.
    }

    /// Ends the current Live Activity immediately.
    public func endRestActivity() {
        guard let activity = currentActivity as? Activity<GymRestAttributes> else { return }
        Task {
            if #available(iOS 16.2, *) {
                let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }
}
#endif
