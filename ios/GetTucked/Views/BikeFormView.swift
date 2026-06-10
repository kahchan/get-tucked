import SwiftUI
import SwiftData

struct BikeFormView: View {
    var isOnboarding: Bool = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var handlebarWidthText = ""
    @State private var bikeType: BikeType = .road

    private var handlebarWidth: Double? {
        Double(handlebarWidthText)
    }

    private var isValid: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        (handlebarWidth ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isOnboarding {
                HStack {
                    Text("New Bike")
                        .font(.headline)
                    Spacer()
                    Button("Cancel") { dismiss() }
                }
                .padding()
                Divider()
            }

            Form {
                Section("Bike name") {
                    TextField("e.g. Tour Divide Curve Big Kev", text: $nickname)
                }
                Section("Type") {
                    Picker("Type", selection: $bikeType) {
                        ForEach(BikeType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    HStack {
                        TextField("420", text: $handlebarWidthText)
                            .keyboardType(.numberPad)
                        Text("mm")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Handlebar width")
                } footer: {
                    Text("Measured centre-to-centre. This sets the scale for every measurement on this bike.")
                }
            }

            Button(action: save) {
                Text(isOnboarding ? "Get started" : "Save bike")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func save() {
        guard let width = handlebarWidth, isValid else { return }
        let bike = Bike(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            handlebarWidthMm: width,
            bikeType: bikeType
        )
        context.insert(bike)
        dismiss()
    }
}
