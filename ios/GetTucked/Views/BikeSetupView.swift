import SwiftUI
import SwiftData

/// Add / edit a bike. Monospace inputs with bottom-border only (no Form).
struct BikeSetupView: View {
    /// When set, the screen edits this bike in place instead of creating a new one.
    var editing: Bike? = nil
    var onSave: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var handlebarWidthText = ""
    @State private var bikeType: BikeType = .road
    @State private var showHandlebarTip = false
    @State private var didLoad = false
    @State private var showDeleteConfirm = false

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
                    Text(editing == nil ? "BIKE SETUP" : "EDIT BIKE")
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

                VStack(spacing: Theme.Space.sm) {
                    AccentButton(label: editing == nil ? "SAVE BIKE" : "SAVE CHANGES",
                                 action: save, enabled: isValid)
                    if editing != nil {
                        GhostButton(label: "DELETE BIKE") { showDeleteConfirm = true }
                    }
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.md)
            }
        }
        .onAppear(perform: loadIfNeeded)
        .confirmationDialog(deleteMessage, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete bike", role: .destructive, action: deleteBike)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var deleteMessage: String {
        let count = editing?.positions.count ?? 0
        return count == 0
            ? "Delete this bike?"
            : "Delete this bike and its \(count) saved position\(count == 1 ? "" : "s")?"
    }

    private func loadIfNeeded() {
        guard !didLoad, let bike = editing else { return }
        didLoad = true
        nickname = bike.nickname
        handlebarWidthText = String(Int(bike.handlebarWidthMm))
        bikeType = bike.bikeType
    }

    private func save() {
        guard let width = handlebarWidth, isValid else { return }
        let name = nickname.trimmingCharacters(in: .whitespaces)
        if let bike = editing {
            bike.nickname = name
            bike.handlebarWidthMm = width
            bike.bikeType = bikeType
        } else {
            context.insert(Bike(nickname: name, handlebarWidthMm: width, bikeType: bikeType))
        }
        onSave?()
        dismiss()
    }

    private func deleteBike() {
        guard let bike = editing else { return }
        context.delete(bike)   // cascades to the bike's positions
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
            .font(Theme.mono(11, weight: .bold))
            .foregroundStyle(Theme.Palette.fg2)
            .kerning(0.8)
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
                        .font(Theme.mono(12, weight: selected ? .bold : .regular))
                        .foregroundStyle(selected ? Color.black : Theme.Palette.fg2)
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
