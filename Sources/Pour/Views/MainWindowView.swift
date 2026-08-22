import AppKit
import DesignKit
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case transcriptions = "Transcriptions"
    case dictionary = "Dictionary"
    case settings = "Settings"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .transcriptions: "text.bubble"
        case .dictionary: "character.book.closed"
        case .settings: "gearshape"
        }
    }
}

struct MainWindowView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $model.selectedSidebarSection) {
                    ForEach(SidebarSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.symbol)
                            .font(PourFont.body(13))
                            .padding(.vertical, PourSpace.xxs)
                            .tag(section)
                    }
                }

                HStack {
                    Spacer()
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 64, height: 64)
                        .accessibilityLabel("Pour app icon")
                }
                .padding(.horizontal, PourSpace.sm)
                .padding(.bottom, PourSpace.sm)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
            .background(PourColor.bgAlt)
        } detail: {
            Group {
                switch model.selectedSidebarSection ?? .transcriptions {
                case .transcriptions: TranscriptionsView()
                case .dictionary: DictionaryView()
                case .settings: SettingsView()
                }
            }
            .background(PourColor.bgCanvas)
        }
        .background(PourColor.bgCanvas)
    }
}
