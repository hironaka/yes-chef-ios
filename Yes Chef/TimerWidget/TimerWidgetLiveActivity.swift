import ActivityKit
import WidgetKit
import SwiftUI

struct TimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // Lock screen/banner UI
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                    Text(context.attributes.timerName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                }
                
                if context.state.isPaused {
                    Text("Paused")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text(timerInterval: Date()...context.state.estimatedEndTime, countsDown: true)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .activityBackgroundTint(Color(UIColor.secondarySystemBackground))
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                        Text(context.attributes.timerName)
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(alignment: .center) {
                        if context.state.isPaused {
                            Text("Paused")
                                .font(.headline)
                                .font(.title)
                                .foregroundColor(.secondary)
                        } else {
                            Text(timerInterval: Date()...context.state.estimatedEndTime, countsDown: true)
                                .font(.title)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
            } compactTrailing: {
                if context.state.isPaused {
                    Text("Paused")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text(timerInterval: Date()...context.state.estimatedEndTime, countsDown: true)
                        .multilineTextAlignment(.trailing)
                }
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
            }
            .widgetURL(URL(string: "yeschef://timer"))
            .keylineTint(Color.orange)
        }
    }
}

extension TimerAttributes {
    fileprivate static var preview: TimerAttributes {
        TimerAttributes(timerName: "Boiling Eggs")
    }
}

extension TimerAttributes.ContentState {
    fileprivate static var running: TimerAttributes.ContentState {
        TimerAttributes.ContentState(isPaused: false, estimatedEndTime: Date().addingTimeInterval(5 * 60))
     }
     
     fileprivate static var paused: TimerAttributes.ContentState {
         TimerAttributes.ContentState(isPaused: true, estimatedEndTime: Date().addingTimeInterval(3 * 60))
     }
}

#Preview("Notification", as: .content, using: TimerAttributes.preview) {
   TimerWidgetLiveActivity()
} contentStates: {
    TimerAttributes.ContentState.running
    TimerAttributes.ContentState.paused
}
