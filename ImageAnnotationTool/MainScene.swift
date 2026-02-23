import SwiftUI

struct MainScene: Scene {
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 400, minHeight: 300)
                .background(AlwaysOnTop())
        }
        .commands {
            AboutCommand()
            SidebarCommands()
            ExportCommands()
            AlwaysOnTopCommand()
            MyCommands()
        }
        Settings {
            SettingsWindow()
        }
    }
}
