import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case appearance = "外观设置"
    case subscriptions = "日历订阅"
    case general = "通用"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .appearance: "paintpalette"
        case .subscriptions: "calendar.badge.plus"
        case .general: "gearshape"
        }
    }
}

/// One selection shared by the AppKit window and its two hosted SwiftUI panes.
@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var selection: SettingsPage = .appearance
}

struct SettingsSidebarView: View {
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        List(selection: $navigation.selection) {
            ForEach(SettingsPage.allCases) { page in
                Label(page.rawValue, systemImage: page.symbol)
                    .tag(page)
            }
        }
        .listStyle(.sidebar)
        // The NSSplitViewItem supplies the system sidebar glass.
        .scrollContentBackground(.hidden)
    }
}

@MainActor
struct SettingsView: View {
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var loginItemViewModel: LoginItemViewModel
    @ObservedObject var appUpdateViewModel: AppUpdateViewModel

    var body: some View {
        Group {
            switch navigation.selection {
            case .appearance:
                AppearanceSettingsView()
            case .subscriptions:
                CalendarSubscriptionsSettingsView(store: .shared)
            case .general:
                GeneralSettingsView(
                    loginItemViewModel: loginItemViewModel,
                    appUpdateViewModel: appUpdateViewModel
                )
            }
        }
        .id(navigation.selection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toggleStyle(.switch)
        .controlSize(.small)
        .alert(
            "无法更新登录项",
            isPresented: Binding(
                get: { loginItemViewModel.errorMessage != nil },
                set: { if !$0 { loginItemViewModel.errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(loginItemViewModel.errorMessage ?? "")
        }
        .alert(item: $appUpdateViewModel.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("好"))
            )
        }
    }
}
