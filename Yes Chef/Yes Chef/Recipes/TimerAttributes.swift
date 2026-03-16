//
//  TimerAttributes.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 3/16/26.
//

import Foundation
import ActivityKit

struct TimerAttributes: ActivityAttributes {
    // 1. ContentState: Dynamic data that might change while the timer is running
    // (For a simple timer, you might not even need to change anything here,
    // but it's required by the protocol).
    public struct ContentState: Codable, Hashable {
        var isPaused: Bool = false
        var estimatedEndTime: Date
    }

    // 2. Static data: Set once when the timer starts
    var timerName: String
}
