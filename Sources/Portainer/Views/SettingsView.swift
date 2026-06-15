import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ContainerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apple container CLI")
                        .font(.system(size: 13, weight: .semibold))
                    HStack {
                        Text("Command")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                        Spacer()
                        Text("container")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.ink)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(AppTheme.surfaceRaised.opacity(0.74), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text("This build targets Apple's `container` CLI only. Use Refresh after changing runtime state outside the app.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.muted)
                }

                Stepper("Log line limit: \(store.logLineLimit)", value: $store.logLineLimit, in: 50...1000, step: 50)
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()
        }
        .padding(28)
        .background(AppBackground())
    }
}
