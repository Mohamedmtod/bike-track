import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Shared ActivityKit attributes for ProBike Gym Rest Timer.
/// Compatible with iOS 16.1+ on iPhone 14 Pro (Dynamic Island & Lock Screen).
@available(iOS 16.1, *)
public struct GymRestAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var restEndTime: Date
        public var totalSeconds: Int
        public var exerciseName: String
        public var setNumber: Int

        public init(
            restEndTime: Date,
            totalSeconds: Int,
            exerciseName: String,
            setNumber: Int
        ) {
            self.restEndTime = restEndTime
            self.totalSeconds = totalSeconds
            self.exerciseName = exerciseName
            self.setNumber = setNumber
        }
    }

    public var sessionTitle: String

    public init(sessionTitle: String = "ProBike Gym Rest") {
        self.sessionTitle = sessionTitle
    }
}
#endif
