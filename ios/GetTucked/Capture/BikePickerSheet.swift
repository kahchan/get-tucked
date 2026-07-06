import SwiftUI
import SwiftData

/// Capture-time bike switcher with inline add-bike (Plan E2). Full bike
/// management (edit/delete) lives in `BikeListView`; this is just the
/// capture-time picker (prototype `b554d774.js:479`).
struct BikePickerSheet: View {
    let bikes: [Bike]
    let selected: Bike
    let onPick: (Bike) -> Void

    @Environment(\.modelContext) private var context
    @State private var addingBike = false
    @State private var nickname = ""
    @State private var handlebarWidthText = ""
    @State private var bikeType: BikeType = .road
    @State private var pendingSelection: Bike?

    private var isValid: Bool {
        Bike.isValidInput(nickname: nickname, handlebarWidthText: handlebarWidthText)
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(
                    title: "SHOOTING ON",
                    subtitle: "Each bike's handlebar width is the ruler that turns pixels into centimetres."
                )
                SectionDivider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(bikes, id: \.id) { bike in
                            Button {
                                select(bike, after: 0.18)
                            } label: {
                                BikePickerRow(bike: bike, isSelected: (pendingSelection ?? selected).id == bike.id)
                            }
                            .buttonStyle(.plain)
                            SectionDivider()
                        }

                        Button {
                            addingBike.toggle()
                            if !addingBike { resetForm() }
                        } label: {
                            HStack(spacing: Theme.Space.sm) {
                                Text(addingBike ? "×" : "+")
                                    .font(Theme.mono(16))
                                    .foregroundStyle(Theme.Palette.acc)
                                    .frame(width: 20, alignment: .center)
                                Text(addingBike ? "CANCEL" : "ADD A BIKE")
                                    .font(Theme.mono(11, weight: .bold))
                                    .foregroundStyle(Theme.Palette.acc)
                                    .kerning(0.8)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Space.lg)
                            .frame(height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        SectionDivider()

                        if addingBike {
                            VStack(alignment: .leading, spacing: 0) {
                                FieldLabel("NICKNAME")
                                    .padding(.top, Theme.Space.md)
                                MonoField(placeholder: "Winter trainer", text: $nickname)

                                FieldLabel("TYPE")
                                    .padding(.top, Theme.Space.md)
                                TypeToggle(selection: $bikeType)

                                FieldLabel("HANDLEBAR WIDTH (MM)")
                                    .padding(.top, Theme.Space.md)
                                MonoField(placeholder: "420", text: $handlebarWidthText, numericOnly: true)

                                AccentButton(label: "SAVE & SELECT", action: saveBike, enabled: isValid)
                                    .padding(.horizontal, Theme.Space.lg)
                                    .padding(.top, Theme.Space.lg)
                                    .padding(.bottom, Theme.Space.lg)
                            }
                        }
                    }
                }
            }
        }
        .hideNavBar()
    }

    private func resetForm() {
        nickname = ""
        handlebarWidthText = ""
        bikeType = .road
    }

    private func select(_ bike: Bike, after seconds: Double) {
        pendingSelection = bike
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            onPick(bike)
        }
    }

    private func saveBike() {
        guard isValid, let width = Double(handlebarWidthText) else { return }
        let bike = Bike(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            handlebarWidthMm: width,
            bikeType: bikeType
        )
        context.insert(bike)
        addingBike = false
        resetForm()
        select(bike, after: 0.22)
    }
}

private struct BikePickerRow: View {
    let bike: Bike
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.md) {
            ZStack {
                Rectangle()
                    .stroke(isSelected ? Theme.Palette.acc : Theme.Palette.line, lineWidth: 1)
                    .frame(width: 18, height: 18)
                if isSelected {
                    Rectangle().fill(Theme.Palette.acc).frame(width: 10, height: 10)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(bike.nickname)
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundStyle(Theme.Palette.fg)
                Text("\(Int(bike.handlebarWidthMm)) MM · \(bike.bikeType.displayName.uppercased())")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 60)
        .contentShape(Rectangle())
    }
}
