//
//  SteadyTodayApp.swift
//  SteadyToday
//
//  Created by 85114 on 1/14/26.
//

import SwiftUI
import SwiftData

@main
struct SteadyTodayApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlanYear.self,
            MandalartCategory.self,
            RoutineAction.self,
            ActionCheck.self,
            TimeSession.self,
            GratitudeEntry.self,
        ])
        
        // Use an explicit local store URL so we can recover cleanly during development
        // when the schema changes (SwiftData doesn't auto-migrate in many cases).
        let storeURL: URL = {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            return base.appendingPathComponent("SteadyToday.sqlite")
        }()
        
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Dev-friendly recovery: if the existing local store is incompatible after schema changes,
            // delete it and retry. For production, you'd implement proper migration instead.
            let fm = FileManager.default
            try? fm.removeItem(at: storeURL)
            try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
            try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
            
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                // Last resort: launch with in-memory storage (prevents crash loop).
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do { return try ModelContainer(for: schema, configurations: [fallback]) }
                catch { fatalError("Could not create ModelContainer: \(error)") }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
