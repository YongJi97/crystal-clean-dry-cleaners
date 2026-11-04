import SwiftUI
import UserNotifications

struct RootView: View {
    @State private var model: AppModel

    init() {
        _model = State(initialValue: MainActor.assumeIsolated { AppModel() })
    }

    var body: some View {
        TabView(selection: $model.selectedTab) {
            ServicesView(model: model)
                .tabItem { Label("Services", systemImage: "tag") }
                .tag(AppTab.services)
            RequestPickupView(model: model)
                .tabItem { Label("Pickup", systemImage: "truck.box") }
                .tag(AppTab.pickup)
            MyRequestsView(model: model)
                .tabItem { Label("Requests", systemImage: "list.bullet") }
                .tag(AppTab.requests)
            ProfileView(model: model)
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(AppTab.profile)
        }
        .tint(Color("AccentColor"))
        .onAppear {
            UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        }
    }
}
