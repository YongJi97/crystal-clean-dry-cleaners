import SwiftUI

struct ProfileView: View {
    @Bindable var model: AppModel
    @State private var confirmClear = false
    @FocusState private var addressFocused: Bool
    @StateObject private var addressSearch = AddressCompleter()

    var body: some View {
        NavigationStack {
            Form {
                Section("Saved for the pickup form") {
                    TextField("Name", text: $model.profile.name)
                        .textContentType(.name)
                    TextField("Phone", text: $model.profile.phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $model.profile.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Address", text: $model.profile.address)
                        .textContentType(.fullStreetAddress)
                        .focused($addressFocused)
                        .onChange(of: model.profile.address) { _, newValue in
                            addressSearch.update(query: newValue)
                        }
                    if addressFocused {
                        ForEach(addressSearch.suggestions) { suggestion in
                            Button {
                                let formatted = suggestion.formattedAddress
                                model.profile.address = formatted
                                addressSearch.accept(formatted)
                                KeyboardFocus.clear()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .foregroundStyle(.primary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    AddressLine2Field(text: $model.profile.addressLine2)
                }
                Section {
                    Button("Clear my data", role: .destructive) {
                        confirmClear = true
                    }
                } footer: {
                    Text("Your name, phone, email, and address are saved on this phone as you type.")
                        .font(.footnote)
                }
            }
            .contentMargins(.bottom, 24, for: .scrollContent)
            .dismissesKeyboardInteractively()
            .navigationTitle("Profile")
            .onChange(of: model.profile) { _, _ in
                model.saveProfile()
            }
            .onChange(of: addressFocused) { _, focused in
                if focused {
                    addressSearch.update(query: model.profile.address)
                } else {
                    addressSearch.dismissSuggestions()
                }
            }
            .alert("Clear your data on this phone?", isPresented: $confirmClear) {
                Button("Clear", role: .destructive) {
                    model.clearMyData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes your saved profile and pickup history from this phone. It does not delete a request the shop already received.")
            }
        }
    }
}
