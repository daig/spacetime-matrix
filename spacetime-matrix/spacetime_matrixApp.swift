//
//  spacetime_matrixApp.swift
//  spacetime-matrix
//
//  Created by David Girardo on 3/15/25.
//

import SwiftUI

@main
struct spacetime_matrixApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView().environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full) // Changed to .full
    }
}
