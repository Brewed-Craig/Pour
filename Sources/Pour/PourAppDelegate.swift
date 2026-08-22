import AppKit
import DesignKit
import FlowCore

@MainActor
final class PourAppDelegate: NSObject, NSApplicationDelegate {

    let model = AppModel()
    private var statusItem: StatusItemController?
    private var hud: HUDController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistrar.registerAll()

        hud = HUDController(model: model)

        let statusItem = StatusItemController(model: model)
        statusItem.onRetry = { [weak self] in
            Task { await self?.bootstrap() }
        }
        statusItem.onQuit = {
            NSApplication.shared.terminate(nil)
        }
        statusItem.onShowWindow = {
            NSApp.activate(ignoringOtherApps: true)
            // The HUD's NSPanel is borderless; the main window is titled — this
            // reliably finds the main window regardless of the HUD's visibility.
            NSApp.windows.first(where: { $0.styleMask.contains(.titled) })?.makeKeyAndOrderFront(nil)
        }
        self.statusItem = statusItem

        model.onDeliveredEntry = { [weak statusItem] entry in
            statusItem?.renderDelivered(entry)
        }

        Task { await bootstrap() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.controller.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Pour keeps dictating from the menu bar even with the window closed.
        false
    }

    private func bootstrap() async {
        await model.bootstrap { [weak self] fraction in
            Task { @MainActor in
                self?.statusItem?.showDownloadProgress(fraction)
            }
        }
    }
}
