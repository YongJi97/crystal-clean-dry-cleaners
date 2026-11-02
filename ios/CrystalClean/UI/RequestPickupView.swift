import SwiftUI

struct RequestPickupView: View {
    @Bindable var model: AppModel
    @State private var didAttemptSubmit = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $model.pickupDraft.name)
                        .textContentType(.name)
                    TextField("Phone", text: $model.pickupDraft.phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    if showPhoneError {
                        Text("Please enter a valid 10-digit phone number.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    TextField("Email (optional)", text: $model.pickupDraft.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("Pickup") {
                    TextField("Pickup address", text: $model.pickupDraft.address)
                        .textContentType(.fullStreetAddress)
                    AddressLine2Field(text: $model.pickupDraft.addressLine2)
                    TextField("Preferred date & time", text: $model.pickupDraft.when)
                    TextField("Notes (optional)", text: $model.pickupDraft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let error = model.submitError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button {
                        didAttemptSubmit = true
                        Task { await model.submitPickup() }
                    } label: {
                        if model.isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Send pickup request")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(model.isSubmitting)
                }
            }
            .contentMargins(.bottom, 24, for: .scrollContent)
            .navigationTitle("Request Pickup")
            .navigationDestination(isPresented: $model.showConfirmation) {
                ConfirmationView(referenceID: model.lastReferenceID)
            }
            .onAppear {
                model.preparePickupForm()
                model.replayConfirmationIfNeeded()
            }
            .onChange(of: model.draftRevision) { _, _ in
                didAttemptSubmit = false
            }
        }
    }

    private var showPhoneError: Bool {
        didAttemptSubmit && !PhoneValidation.isValid(model.pickupDraft.phone)
    }
}

struct AddressLine2Field: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Apt, suite, floor")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Apt, suite, floor", text: $text)
                .textContentType(.streetAddressLine2)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ConfirmationView: View {
    var referenceID: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(red: 44 / 255, green: 111 / 255, blue: 174 / 255))
            Text("Request received")
                .font(.title2.bold())
            Text("We’ll confirm your pickup. Save this reference.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(referenceID)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .navigationTitle("Confirmation")
        .navigationBarTitleDisplayMode(.inline)
    }
}
