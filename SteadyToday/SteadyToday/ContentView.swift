//
//  ContentView.swift
//  SteadyToday
//
//  Created by 85114 on 1/14/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Image(systemName: "checkmark.circle") }

            MandalartView()
                .tabItem { Image(systemName: "square.grid.3x3") }

            HistoryView()
                .tabItem { Image(systemName: "clock") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            PlanYear.self,
            MandalartCategory.self,
            RoutineAction.self,
            ActionCheck.self,
            TimeSession.self,
            GratitudeEntry.self,
        ], inMemory: true)
}
