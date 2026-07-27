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
    // Plan S1: which convention the bar-width tap-calibration measures
    // against. Tracks bikeType's own default until the rider (or a loaded
    // bike) sets it explicitly — see the onChange below.
    @State private var barType: BarType = .drop
    @State private var showHandlebarTip = false
    @State private var didLoad = false
    @State private var showDeleteConfirm = false
    // Wheel size + wheelbase — optional cross-scale verification metadata (Plan K1).
    @State private var showWheelSize = false
    @State private var rimStandard: RimStandard?
    @State private var tireWidthText = ""
    @State private var wheelbaseText = ""

    private var handlebarWidth: Double? { Double(handlebarWidthText) }

    private var isValid: Bool {
        Bike.isValidInput(nickname: nickname, handlebarWidthText: handlebarWidthText)
    }

    /// Plan S1: the real drop-bar issue — quoted width is measured at the
    /// hoods, but the drop ends are what's tappable in a front-on photo.
    private var handlebarWidthTip: String {
        switch barType {
        case .drop:
            return "Measure outside-to-outside at the very ends of the drops — NOT the quoted size (that's measured at the hoods and flared bars are wider at the ends)."
        case .flat:
            return "Outside-to-outside at the bar ends, including bar-end accessories."
        }
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: editing == nil ? "BIKE SETUP" : "EDIT BIKE",
                          subtitle: "Two facts. Then we shoot.") {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: Theme.Control.iconSize, weight: .medium))
                            .foregroundStyle(Theme.Palette.fg3)
                            .frame(width: Theme.Control.iconTapTarget, height: Theme.Control.iconTapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

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

                        // Bar type — sets which convention the width field
                        // and the capture-time tap copy both use (Plan S1).
                        FieldLabel("BAR TYPE")
                            .padding(.top, Theme.Space.md)
                        BarTypeToggle(selection: $barType)
                        SectionDivider()
                            .padding(.top, Theme.Space.lg)

                        // Handlebar width
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                            FieldLabel("HANDLEBAR WIDTH (MM)")
                            Button {
                                showHandlebarTip.toggle()
                            } label: {
                                Text("?")
                                    .font(Theme.mono(11))
                                    .foregroundStyle(Theme.Palette.fg3)
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
                            Text(handlebarWidthTip)
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.Palette.fg3)
                                .padding(.top, Theme.Space.xs)
                                .padding(.horizontal, Theme.Space.screenMargin)
                        }

                        MonoField(placeholder: "420", text: $handlebarWidthText, numericOnly: true)
                        SectionDivider()
                            .padding(.top, Theme.Space.lg)

                        // Wheel size + wheelbase — optional, kept collapsed by
                        // default so the required fields above don't read as
                        // longer/scarier, but still an explicit, discoverable
                        // control rather than hidden functionality.
                        OptionalSectionToggle(
                            label: showWheelSize ? "Hide wheel size" : "Wheel size & wheelbase (optional)",
                            expanded: $showWheelSize
                        )
                        if showWheelSize {
                            WheelSizeFields(rimStandard: $rimStandard, tireWidthText: $tireWidthText, wheelbaseText: $wheelbaseText)
                        }
                        SectionDivider()
                            .padding(.top, Theme.Space.lg)

                        Spacer(minLength: Theme.Space.xl)
                    }
                    .padding(.horizontal, Theme.Space.screenMargin)
                    .padding(.top, Theme.Space.md)
                }

                // Q8.3: AccentButton is always the bottom-most control —
                // primary action at the thumb; side benefit of moving
                // DELETE BIKE off the easiest-reach position.
                VStack(spacing: Theme.Space.sm) {
                    if editing != nil {
                        GhostButton(label: "DELETE BIKE") { showDeleteConfirm = true }
                    }
                    AccentButton(label: editing == nil ? "SAVE BIKE" : "SAVE CHANGES",
                                 action: save, enabled: isValid)
                }
                .padding(.horizontal, Theme.Space.screenMargin)
                .padding(.vertical, Theme.Space.md)
            }
        }
        .hideNavBar()
        .onAppear(perform: loadIfNeeded)
        // Keeps the bar-type default tracking bikeType until the rider (or
        // a loaded bike) picks one explicitly — never fires for `editing`
        // bikes, since loadIfNeeded sets both together after didLoad flips.
        .onChange(of: bikeType) { _, newValue in
            guard editing == nil else { return }
            barType = newValue == .mtb ? .flat : .drop
        }
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
        barType = bike.effectiveBarType
        rimStandard = bike.rimStandard
        let tireWidthUnit = rimStandard?.tireWidthUnit ?? .mm
        tireWidthText = bike.tireWidthMm.map { formattedTireWidth($0, unit: tireWidthUnit) } ?? ""
        wheelbaseText = bike.wheelbaseMm.map { String(Int($0)) } ?? ""
        showWheelSize = rimStandard != nil || bike.tireWidthMm != nil || bike.wheelbaseMm != nil
    }

    private func save() {
        guard let width = handlebarWidth, isValid else { return }
        let name = nickname.trimmingCharacters(in: .whitespaces)
        let bike = editing ?? Bike(nickname: name, handlebarWidthMm: width, bikeType: bikeType)
        bike.nickname = name
        bike.handlebarWidthMm = width
        bike.bikeType = bikeType
        bike.barType = barType
        bike.rimStandard = rimStandard
        bike.tireWidthMm = Double(tireWidthText).map {
            AnalysisMath.tireWidthMm(fromEntry: $0, unit: rimStandard?.tireWidthUnit ?? .mm)
        }
        bike.wheelbaseMm = Double(wheelbaseText)
        if editing == nil { context.insert(bike) }
        onSave?()
        dismiss()
    }

    /// Redisplays a stored mm value in whichever unit its rim standard uses —
    /// integer mm, or inches trimmed to at most 2 decimals ("2.1", not "2.10").
    private func formattedTireWidth(_ mm: Double, unit: TireWidthUnit) -> String {
        let value = AnalysisMath.tireWidthDisplayValue(fromMm: mm, unit: unit)
        switch unit {
        case .mm:
            return String(Int(value.rounded()))
        case .inches:
            var text = String(format: "%.2f", value)
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
            return text
        }
    }

    private func deleteBike() {
        guard let bike = editing else { return }
        context.delete(bike)   // cascades to the bike's positions
        onSave?()
        dismiss()
    }
}

// MARK: - Local sub-views

struct TypeToggle: View {
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
        .padding(.top, Theme.Space.xs)
    }
}

/// Drop/flat picker (Plan S1) — same shape as `TypeToggle`, separate type
/// since BarType and BikeType are independent axes.
struct BarTypeToggle: View {
    @Binding var selection: BarType

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BarType.allCases, id: \.self) { type in
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
        .padding(.top, Theme.Space.xs)
    }
}

/// Collapsed-by-default disclosure for an optional field group — visible and
/// discoverable (unlike a hidden gesture), but doesn't lengthen the form
/// until the rider opts in (Plan K1).
struct OptionalSectionToggle: View {
    let label: String
    @Binding var expanded: Bool

    var body: some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: Theme.Space.xs) {
                Text(expanded ? "−" : "+")
                    .font(Theme.mono(14, weight: .bold))
                Text(label.uppercased())
                    .font(Theme.mono(11, weight: .bold))
                    .kerning(0.5)
                Spacer()
            }
            .foregroundStyle(Theme.Palette.fg3)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Rim-size picker — five ISO bead-seat standards across two rows so every
/// option stays visible (no horizontal scroll to hide a choice). Tapping the
/// selected standard again deselects it, since this field is optional.
struct RimStandardToggle: View {
    @Binding var selection: RimStandard?

    private let topRow: [RimStandard] = [.c700, .b650, .in26]
    private let bottomRow: [RimStandard] = [.in275, .in29]

    var body: some View {
        VStack(spacing: 1) {
            row(topRow)
            row(bottomRow)
        }
        .padding(.top, Theme.Space.xs)
    }

    private func row(_ standards: [RimStandard]) -> some View {
        HStack(spacing: 0) {
            ForEach(standards, id: \.self) { standard in
                let selected = selection == standard
                Button {
                    selection = selected ? nil : standard
                } label: {
                    Text(standard.displayName)
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
    }
}

/// Rim standard + tire width + wheelbase — shared by `BikeSetupView` and the
/// capture-time bike picker's inline add form (Plan K1).
struct WheelSizeFields: View {
    @Binding var rimStandard: RimStandard?
    @Binding var tireWidthText: String
    @Binding var wheelbaseText: String

    // Road/gravel tires read in mm off the sidewall ("700x40c"); mountain
    // bike tires in inches ("27.5x2.35") — default to mm until a rim
    // standard narrows it down.
    private var tireWidthUnit: TireWidthUnit { rimStandard?.tireWidthUnit ?? .mm }

    var body: some View {
        // `lg` between each field group, not `md`: the main form separates
        // its fields with a divider plus ~40pt of air, so a bare `md` (16)
        // here made the optional wheel fields read noticeably tighter than
        // the core fields directly above them. This section stays
        // dividerless (it's a lighter, optional sub-group) but breathes at a
        // comparable rhythm.
        Group {
            FieldLabel("RIM SIZE")
                .padding(.top, Theme.Space.lg)
            RimStandardToggle(selection: $rimStandard)

            FieldLabel(tireWidthUnit.fieldLabel)
                .padding(.top, Theme.Space.lg)
            MonoField(placeholder: tireWidthUnit.placeholder, text: $tireWidthText, numericOnly: true)

            FieldLabel("WHEELBASE (MM)")
                .padding(.top, Theme.Space.lg)
            MonoField(placeholder: "1050", text: $wheelbaseText, numericOnly: true)
        }
        // Switching rim families (mm ↔ inches) would otherwise silently
        // reinterpret an already-typed number under the wrong unit — clear
        // it rather than guess. Switching within the same family (e.g.
        // 700C → 650B, both mm) leaves the entry alone.
        .onChange(of: rimStandard) { oldValue, newValue in
            let oldUnit = oldValue?.tireWidthUnit ?? .mm
            let newUnit = newValue?.tireWidthUnit ?? .mm
            if oldUnit != newUnit {
                tireWidthText = ""
            }
        }
    }
}
