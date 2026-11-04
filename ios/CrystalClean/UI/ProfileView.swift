import SwiftUI

struct ProfileView: View {
    @Bindable var model: AppModel
    @State private var confirmClear = false

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
                    AddressLine2Field(text: $model.profile.addressLine2)
                }
                Section {
                    if let privacyURL = URL(string: "https://www.crystalcleandrycleaner.com/privacy.html") {
                        Link("Privacy policy", destination: privacyURL)
                    }
                    Button("Clear my data", role: .destructive) {
                        confirmClear = true
                    }
                } footer: {
                    Text("Your name, phone, email, and address are saved on this phone as you type.")
                        .font(.footnote)
                }
            }
            .contentMargins(.bottom, 24, for: .scrollContent)
            .navigationTitle("Profile")
            .onChange(of: model.profile) { _, _ in
                model.saveProfile()
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
