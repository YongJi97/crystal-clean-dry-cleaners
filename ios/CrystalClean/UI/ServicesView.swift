import SwiftUI

struct ServicesView: View {
    var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.catalog.categories.isEmpty {
                    ContentUnavailableView(
                        "Prices unavailable",
                        systemImage: "tag",
                        description: Text("Connect once to download the price list. A saved copy is used offline.")
                    )
                } else {
                    List {
                        ForEach(model.catalog.categories) { category in
                            Section {
                                if let summary = category.summary {
                                    Text(summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(category.items) { item in
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                            if let notes = item.notes {
                                                Text(notes)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer(minLength: 12)
                                        Text(PriceFormat.line(item))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color(red: 31 / 255, green: 92 / 255, blue: 151 / 255))
                                    }
                                }
                                if let notes = category.notes, category.layout != "feature" {
                                    Text(notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                if let detail = category.detail {
                                    Text(detail)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } header: {
                                Text(category.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Services & Prices")
            .task { await model.loadCatalog() }
        }
    }
}
