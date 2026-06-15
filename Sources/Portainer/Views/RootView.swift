import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ContainerStore

    var body: some View {
        if store.uiMode == .drawer {
            DrawerModeView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sheet(isPresented: $store.isRunContainerPresented) {
                    RunContainerSheet()
                        .environmentObject(store)
                }
        } else {
            fullModeView
                .sheet(isPresented: $store.isRunContainerPresented) {
                    RunContainerSheet()
                        .environmentObject(store)
                }
        }
    }

    private var fullModeView: some View {
        ZStack {
            AppBackground()

            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: 226)

                Divider()
                    .overlay(Color.white.opacity(0.22))

                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
            }
            .shadow(color: Color(hex: 0x6F86B8, alpha: 0.13), radius: 30, x: 0, y: 18)
            .padding(12)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Color.white.opacity(0.032)
                .background(.ultraThinMaterial)

            VStack(spacing: 14) {
                if let issue = store.runtimeIssue {
                    RuntimeIssueBanner(issue: issue)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let issue = store.operationIssue {
                    RuntimeIssueBanner(issue: issue)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                switch store.selectedSection {
                case .dashboard:
                    DashboardView()
                case .containers:
                    if store.selectedContainerID != nil,
                       store.selectedRows.count == 1,
                       store.filteredContainers.contains(where: { $0.id == store.selectedContainerID }) {
                        ContainerDetailView()
                    } else {
                        ContainersListView()
                    }
                case .images:
                    ImagesView()
                case .networks:
                    NetworksView()
                case .volumes:
                    VolumesView()
                case .compose:
                    ComposeView()
                case .configs:
                    ConfigsView()
                case .secrets:
                    SecretsView()
                case .events:
                    EventsView()
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 32)
            .padding(.bottom, 34)
        }
    }
}

struct PlaceholderSectionView: View {
    var section: SidebarSection

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(section.rawValue)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            GlassCard(cornerRadius: 16, padding: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: section.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                    Text("\(section.rawValue) is not exposed as a first-class Apple container CLI resource.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("The button stays disabled until there is a real CLI-backed workflow to show here.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }
    }
}
