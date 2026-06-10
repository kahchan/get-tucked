import SwiftUI

struct BikeOnboardingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bicycle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Add your first bike")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Get Tucked uses your handlebar width to calculate real-world frontal area.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            BikeFormView(isOnboarding: true)
                .padding(.horizontal, 24)
            Spacer()
        }
    }
}
