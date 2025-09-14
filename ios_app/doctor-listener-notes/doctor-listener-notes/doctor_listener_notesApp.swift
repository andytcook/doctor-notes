//
//  doctor_listener_notesApp.swift
//  doctor-listener-notes
//
//  Created by Andras Cook on 9/2/25.
//

import SwiftUI

@main
struct doctor_listener_notesApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // Ensure prompt files exist on app start
                    PromptFileManager.shared.ensurePromptFilesExist()
                }
        }
    }
}
