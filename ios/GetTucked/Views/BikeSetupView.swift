import SwiftUI
import SwiftData

/// Add / edit a bike. Monospace inputs with bottom-border only (no Form).
struct BikeSetupView: View {
    var onSave: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var handlebarWidthText = ""
    @State private var bikeType: BikeType = .road
    @State private var showHandlebarTip = false

    private var handlebarWidth: Double? { Double(handlebarWidthText) }

    private var isValid: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        (handlebarWidth ?? 0) > 0
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Title bar
                HStack {
                    Text("BIKE SETUP")
                        .font(Theme.heading(22))
                        .foregroundStyle(Theme.Palette.fg)
                    Spacer()
                }
                .padding(.horizontal, Theme.Space.lg)
                .frame(height: 56)

                SectionDivider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Bike name
                        FieldLabel("BIKE NAME")
                        MonoField(placeholder: "e.g. Tour Divide Curve", text: $nickname)
                        SectionDivider()
                            .padding(.top, Theme.Space.lg)

                        // Type picker
                        FieldLabel("TYPE")
                            .padding(.top, Theme.Space.md)
                        TypeToggle(selection: $bikeType)
                        SectionDivider()
                            .padding(.top, Theme.Space.lg)

                        // Handlebar width
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                            FieldLabel("HANDLEBAR WIDTH (MM)")
                            Button {
                                showHandlebarTip.toggle()
                            } label: {
                                Text("?")
                                    .font(Theme.mono(10))
                                    .foregroundStyle(Theme.Palette.fg4)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Theme.Palette.line, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, Theme.Space.md)

                        if showHandlebarTip {
                            Text("Centre-to-centre in mm. This sets the scale for every measurement on this bike.")
                                .font(Theme.mono(11))
                                .foregroundStyle(Theme.Palette.fg3)
                                .padding(.top, Theme.Space.xs)
                                .padding(.horizontal, Theme.Space.lg)
                        }

                        MonoField(placeholder: "420", text: $handlebarWidthText, numericOnly: true)
                        SectionDivider()
                            .padding(.top, Theme.Space.lg)

                        Spacer(minLength: Theme.Space.xl)
                    }
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.md)
                }

                AccentButton(label: "SAVE BIKE", action: save, enabled: isValid)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.md)
            }
        }
    }

    private func save() {
        guard let width = handlebarWidth, isValid else { return }
        let bike = Bike(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            handlebarWidthMm: width,
            bikeType: bikeType
        )
        context.insert(bike)
        onSave?()
        dismiss()
    }
}

// MARK: - Local sub-views

private struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.mono(10))
            .foregroundStyle(Theme.Palette.fg4)
            .kerning(0.3)
            .padding(.horizontal, Theme.Space.lg)
    }
}

private struct MonoField: View {
    let placeholder: String
    @Binding var text: String
    var numericOnly: Bool = false

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Theme.mono(18))
            .foregroundStyle(Theme.Palette.fg)
            #if canImport(UIKit)
            .keyboardType(numericOnly ? .numberPad : .default)
            #endif
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.xs)
            .padding(.bottom, Theme.Space.sm)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.Palette.line)
                    .frame(height: 1)
            }
    }
}

private struct TypeToggle: View {
    @Binding var selection: BikeType

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BikeType.allCases, id: \.self) { type in
                let selected = selection == type
                Button {
                    selection = type
                } label: {
                    Text(type.displayName.uppercased())
                        .font(Theme.mono(11, weight: selected ? .bold : .regular))
                        .foregroundStyle(selected ? Color.black : Theme.Palette.fg3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(selected ? Theme.Palette.acc : Color.clear)
                        .overlay(
                            Rectangle()
                                .stroke(Theme.Palette.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.xs)
    }
}
