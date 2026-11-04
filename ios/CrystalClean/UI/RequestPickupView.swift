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
                    DatePicker(
                        "Preferred date & time",
                        selection: $model.pickupDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField("Notes (optional)", text: $model.pickupDraft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let error = model.submitError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .contentMargins(.bottom, 16, for: .scrollContent)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                submitButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(.background)
            }
            .navigationTitle("Request Pickup")
            .navigationDestination(isPresented: $model.showConfirmation) {
                ConfirmationView(referenceID: model.lastReferenceID, shop: model.catalog.shop)
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

    private var submitButton: some View {
        Button {
            didAttemptSubmit = true
            Task { await model.submitPickup() }
        } label: {
            Group {
                if model.isSubmitting {
                    ProgressView()
                } else {
                    Text("Send pickup request")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(model.isSubmitting)
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
    var shop: ShopInfo?
    @ScaledMetric(relativeTo: .largeTitle) private var markSize: CGFloat = 56

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: markSize))
                .foregroundStyle(Color("Brand"))
                .accessibilityHidden(true)
            Text(ConfirmationCopy.title(for: referenceID))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("We’ll confirm your pickup.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let label = ConfirmationCopy.referenceLabel(for: referenceID) {
                Text(label)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
            CallShopLink(shop: shop)
        }
        .padding()
        .navigationTitle("Confirmation")
        .navigationBarTitleDisplayMode(.inline)
    }
}
