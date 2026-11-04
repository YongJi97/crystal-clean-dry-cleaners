import SwiftUI

struct MyRequestsView: View {
    var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.history.isEmpty {
                    ContentUnavailableView(
                        "No pickups yet",
                        systemImage: "tray",
                        description: Text("Requests you send are kept on this phone. Reorder copies them into the form.")
                    )
                } else {
                    List(model.history) { request in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(request.name.isEmpty ? "Pickup" : request.name)
                                    .font(.headline)
                                if request.isTest {
                                    Text("Test")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2), in: Capsule())
                                }
                            }
                            Text(request.when)
                                .font(.subheadline)
                            Text(request.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let label = ConfirmationCopy.referenceLabel(for: request.id) {
                                Text(label)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            } else {
                                Text(ConfirmationCopy.title(for: request.id))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(request.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            CallShopLink(shop: model.catalog.shop)
                            Button("Reorder") {
                                model.reorder(request)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                    .contentMargins(.bottom, 24, for: .scrollContent)
                }
            }
            .navigationTitle("My Requests")
        }
    }
}
