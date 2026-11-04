import SwiftUI

struct ServicesView: View {
    var model: AppModel
    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredCategories: [ServiceCategory] {
        ServiceSearch.filter(model.catalog.categories, query: query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.catalog.categories.isEmpty && model.catalog.shop == nil {
                    ContentUnavailableView(
                        "Prices unavailable",
                        systemImage: "tag",
                        description: Text("Connect once to download the price list. A saved copy is used offline.")
                    )
                } else {
                    List {
                        if let shop = model.catalog.shop, trimmedQuery.isEmpty {
                            Section {
                                ShopCard(shop: shop)
                            }
                        }
                        if filteredCategories.isEmpty {
                            ContentUnavailableView(
                                "No matching items",
                                systemImage: "magnifyingglass",
                                description: Text("Try another word, like shirt or hem.")
                            )
                        } else {
                            ForEach(filteredCategories) { category in
                                Section {
                                    if let summary = category.summary, trimmedQuery.isEmpty {
                                        Text(summary)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    ForEach(category.items) { item in
                                        HStack(alignment: .firstTextBaseline) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name)
                                                if let note = ItemExplainers.detail(for: item) {
                                                    Text(note)
                                                        .font(.footnote)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer(minLength: 12)
                                            Text(PriceFormat.line(item))
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color("BrandStrong"))
                                        }
                                    }
                                    if let notes = category.notes, category.layout != "feature" {
                                        Text(notes)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let detail = category.detail, trimmedQuery.isEmpty {
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
                    .contentMargins(.bottom, 24, for: .scrollContent)
                }
            }
            .navigationTitle("Services & Prices")
            .searchable(text: $query, prompt: "Search services")
            .task { await model.loadCatalog() }
        }
    }
}
