//
//  TimerWidgetBundle.swift
//  TimerWidget
//
//  Created by Hannah Hironaka on 3/16/26.
//

import WidgetKit
import SwiftUI

@main
struct TimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerWidget()
        TimerWidgetControl()
        TimerWidgetLiveActivity()
    }
}
