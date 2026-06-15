import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: ContainerStore

    var body: some View {
        VStack(spacing: 0) {
            logo
                .padding(.top, 34)
                .padding(.bottom, 32)

            VStack(spacing: 8) {
                ForEach(SidebarSection.allCases) { section in
                    sidebarButton(section)
                }
            }
            .padding(.horizontal, 18)

            Spacer()

            modeSwitchButton
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(hex: 0xD7E2FF, alpha: 0.22),
                    Color(hex: 0xEDF3FF, alpha: 0.11),
                    Color(hex: 0xD8F0EA, alpha: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(.ultraThinMaterial)
        )
    }

    private var logo: some View {
        VStack(spacing: 12) {
            CalyxLogoMark(size: 48)
                .shadow(color: AppTheme.blue.opacity(0.12), radius: 9, x: 0, y: 5)

            Text("Calyx")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.ink)
        }
    }

    private func sidebarButton(_ section: SidebarSection) -> some View {
        let selected = store.selectedSection == section
        let enabled = section.isImplemented
        return Button {
            guard enabled else { return }
            store.showSection(section)
            if section == .containers {
                store.selectedRows.removeAll()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                Text(section.rawValue)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                Spacer()
            }
            .foregroundStyle(sidebarForeground(selected: selected, enabled: enabled))
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(
                selected && enabled ? Color.white.opacity(0.24) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(selected && enabled ? Color.white.opacity(0.30) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.48)
        .help(enabled ? section.rawValue : "\(section.rawValue) is not implemented in this Apple container CLI build")
    }

    private func sidebarForeground(selected: Bool, enabled: Bool) -> Color {
        guard enabled else { return AppTheme.muted }
        return selected ? AppTheme.blue : AppTheme.ink
    }

    private var modeSwitchButton: some View {
        Button {
            store.setUIMode(.drawer)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drawer Mode")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Compact quick actions")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
            }
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help("Switch to Drawer mode")
    }
}
