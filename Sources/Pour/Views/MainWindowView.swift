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
            List(selection: $model.selectedSidebarSection) {
                ForEach(SidebarSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.symbol)
                        .font(PourFont.body(13))
                        .padding(.vertical, PourSpace.xxs)
                        .tag(section)
                }
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
