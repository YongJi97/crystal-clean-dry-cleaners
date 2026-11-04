import SwiftUI

struct RequestPickupView: View {
    @Bindable var model: AppModel
    @FocusState private var focused: Field?
    @State private var blurred: Set<Field> = []
    @StateObject private var addressSearch = AddressCompleter()

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name *", text: $model.pickupDraft.name)
                        .textContentType(.name)
                        .focused($focused, equals: .name)
                    if let message = shownNameIssue {
                        fieldError(message)
                    }
                    TextField("Phone *", text: $model.pickupDraft.phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .focused($focused, equals: .phone)
                    if let message = shownPhoneIssue {
                        fieldError(message)
                    }
                    TextField("Email (optional)", text: $model.pickupDraft.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .focused($focused, equals: .email)
                }
                Section("Pickup") {
                    TextField("Pickup address *", text: $model.pickupDraft.address)
                        .textContentType(.fullStreetAddress)
                        .focused($focused, equals: .address)
                        .onChange(of: model.pickupDraft.address) { _, newValue in
                            addressSearch.update(query: newValue)
                        }
                    if focused == .address {
                        addressSuggestions
                    }
                    if let message = shownAddressIssue {
                        fieldError(message)
                    }
                    AddressLine2Field(text: $model.pickupDraft.addressLine2)
                    Text("Preferred date & time *")
                    Picker("Preferred date & time", selection: $model.wantsASAP) {
                        Text("ASAP").tag(true)
                        Text("Pick a time").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    if !model.wantsASAP {
                        DatePicker(
                            "Preferred date & time",
                            selection: $model.pickupDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        if let message = shownWhenIssue {
                            fieldError(message)
                        }
                    }
                    TextField("Notes (optional)", text: $model.pickupDraft.notes, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focused, equals: .notes)
                }
                if let error = model.submitError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .contentMargins(.bottom, 16, for: .scrollContent)
            .dismissesKeyboardInteractively()
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
            .onChange(of: focused) { previous, newValue in
                if let previous {
                    blurred.insert(previous)
                }
                if newValue == .address {
                    addressSearch.update(query: model.pickupDraft.address)
                } else {
                    addressSearch.dismissSuggestions()
                }
            }
            .onChange(of: model.draftRevision) { _, _ in
                blurred = []
                addressSearch.dismissSuggestions()
            }
        }
    }

    private var whenText: String {
        model.wantsASAP ? PickupSchedule.asap : PickupSchedule.format(model.pickupDate)
    }

    private var canSend: Bool {
        guard PickupValidation.isReady(
            name: model.pickupDraft.name,
            phone: model.pickupDraft.phone,
            address: model.pickupDraft.address,
            when: whenText
        ) else { return false }
        if model.wantsASAP { return true }
        return model.pickupDate >= Date().addingTimeInterval(-60)
    }

    private var shownNameIssue: String? {
        blurred.contains(.name) ? PickupValidation.nameIssue(model.pickupDraft.name) : nil
    }

    private var shownPhoneIssue: String? {
        let phone = model.pickupDraft.phone
        let typed = !PickupDraft.trimmed(phone).isEmpty
        guard typed || blurred.contains(.phone) else { return nil }
        return PickupValidation.phoneIssue(phone)
    }

    private var shownAddressIssue: String? {
        blurred.contains(.address) ? PickupValidation.addressIssue(model.pickupDraft.address) : nil
    }

    private var shownWhenIssue: String? {
        guard !model.wantsASAP else { return nil }
        return model.pickupDate >= Date().addingTimeInterval(-60) ? nil : "Choose a future pickup time."
    }

    @ViewBuilder
    private var addressSuggestions: some View {
        ForEach(addressSearch.suggestions) { suggestion in
            Button {
                choose(suggestion)
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

    private func choose(_ suggestion: AddressSuggestion) {
        let formatted = suggestion.formattedAddress
        model.pickupDraft.address = formatted
        addressSearch.accept(formatted)
        KeyboardFocus.clear()
    }

    private func fieldError(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
    }

    private var submitButton: some View {
        Button {
            KeyboardFocus.clear()
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
        .disabled(model.isSubmitting || !canSend)
    }

    private enum Field: Hashable {
        case name, phone, email, address, notes
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
    }
}

struct ConfirmationView: View {
    var referenceID: String
    var shop: ShopInfo?
    @ScaledMetric(relativeTo: .largeTitle) private var markSize: CGFloat = 56

    var body: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: markSize, height: markSize)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Crystal Clean")
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
