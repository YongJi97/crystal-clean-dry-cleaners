import SwiftUI

struct ProfileView: View {
    @Bindable var model: AppModel

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
                    TextField("Address line 2", text: $model.profile.addressLine2)
                        .textContentType(.streetAddressLine2)
                }
                Section {
                    Button("Save profile") {
                        model.saveProfile()
                    }
                    if model.profileSaved {
                        Text("Saved on this phone.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .onChange(of: model.profile) { _, _ in
                model.profileSaved = false
            }
        }
    }
}
