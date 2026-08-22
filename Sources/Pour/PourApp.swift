import DesignKit
import SwiftUI

@main
struct PourApp: App {
    @NSApplicationDelegateAdaptor(PourAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Pour") {
            MainWindowView()
                .environment(appDelegate.model)
                .frame(minWidth: 760, minHeight: 520)
                .background(PourColor.bgCanvas)
        }
        .defaultSize(width: 900, height: 620)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Pour") { showAboutPanel() }
            }
            // No separate Settings scene — it's the "Settings" sidebar item in the
            // main window now. Cmd+, jumps there instead of opening another window.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { openSettings() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private func openSettings() {
        appDelegate.model.selectedSidebarSection = .settings
        NSApp.activate(ignoringOtherApps: true)
        // navigationTitle overrides the window's displayed title (it reads
        // "Transcriptions"/"Dictionary"/"Settings", not "Pour"), so pick the main
        // window by style instead: it's titled, the HUD's NSPanel is borderless.
        NSApp.windows.first(where: { $0.styleMask.contains(.titled) })?.makeKeyAndOrderFront(nil)
    }

    private func showAboutPanel() {
        let credits = NSMutableAttributedString(
            string: "A Brewed AI product.\nbrewed-ai.com",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )
        let linkRange = (credits.string as NSString).range(of: "brewed-ai.com")
        credits.addAttribute(.link, value: "https://brewed-ai.com/", range: linkRange)

        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .applicationName: "Pour",
        ])
    }
}
