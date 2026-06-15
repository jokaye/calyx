import AppKit
import SwiftUI

struct DrawerModeView: View {
    @EnvironmentObject private var store: ContainerStore

    private let visibleContainerLimit = 5

    private var drawerContainers: ArraySlice<ContainerItem> {
        store.containers.prefix(visibleContainerLimit)
    }

    private var hiddenContainerCount: Int {
        max(store.containers.count - drawerContainers.count, 0)
    }

    var body: some View {
        ZStack {
            drawerBackdrop

            VStack(spacing: 12) {
                header

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 9) {
                        issueBanners
                        drawerContent
                    }
                    .padding(.vertical, 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var drawerBackdrop: some View {
        ZStack {
            AppBackground()
            Color.white.opacity(0.035)
                .background(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.36), AppTheme.cyan.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color(hex: 0x6E84B6, alpha: 0.16), radius: 24, x: 0, y: 14)
        .padding(10)
    }

    private var header: some View {
        HStack(spacing: 10) {
            trafficLights

            CalyxLogoMark(size: 29)
                .shadow(color: AppTheme.blue.opacity(0.14), radius: 5, x: 0, y: 3)
                .help("Calyx")

            Spacer()

            HStack(spacing: 5) {
                DrawerHeaderButton(icon: "arrow.clockwise", title: store.isRefreshing ? "Refreshing" : "Refresh", disabled: store.isRefreshing) {
                    Task { await store.refresh() }
                }

                DrawerHeaderButton(icon: "plus", title: "Run container") {
                    store.showRunContainer()
                }

                DrawerHeaderButton(icon: "macwindow", title: "Full window mode") {
                    store.setUIMode(.full)
                }

                DrawerHeaderButton(icon: "slider.horizontal.3", title: "Settings") {
                    NSApp.sendAction(#selector(AppDelegate.showSettingsFromUI), to: nil, from: nil)
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 1)
            }
        }
    }

    private var trafficLights: some View {
        HStack(spacing: 8) {
            TrafficLightButton(color: Color(hex: 0xFF5F57), title: "Close") {
                NSApp.keyWindow?.close()
            }
            TrafficLightButton(color: Color(hex: 0xFFBD2E), title: "Minimize") {
                NSApp.keyWindow?.miniaturize(nil)
            }
            TrafficLightButton(color: Color(hex: 0x37C85B), title: "Zoom") {
                NSApp.keyWindow?.zoom(nil)
            }
        }
    }

    @ViewBuilder
    private var issueBanners: some View {
        if let issue = store.runtimeIssue {
            RuntimeIssueBanner(issue: issue)
        }
        if let issue = store.operationIssue {
            RuntimeIssueBanner(issue: issue)
        }
    }

    @ViewBuilder
    private var drawerContent: some View {
        if store.containers.isEmpty {
            DrawerEmptyState()
                .environmentObject(store)
        } else {
            VStack(spacing: 0) {
                ForEach(drawerContainers) { container in
                    DrawerContainerRow(container: container)
                        .environmentObject(store)
                }

                if hiddenContainerCount > 0 {
                    DrawerListFooter(hiddenCount: hiddenContainerCount) {
                        store.showSection(.containers)
                        store.setUIMode(.full)
                    }
                }
            }
            .drawerPanel(cornerRadius: 9)
        }
    }
}

private struct DrawerEmptyState: View {
    @EnvironmentObject private var store: ContainerStore

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "shippingbox")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.blue.opacity(0.78))

            Text("No containers")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.coreInk)

            Text("Run a container or refresh the Apple container CLI state.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.coreMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ActionButton(title: "Run", icon: "plus", tint: AppTheme.blue) {
                    store.showRunContainer()
                }
                ActionButton(title: "Refresh", icon: "arrow.clockwise", tint: AppTheme.coreInk, disabled: store.isRefreshing) {
                    Task { await store.refresh() }
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 178)
        .drawerPanel(cornerRadius: 9)
    }
}

private struct DrawerHeaderButton: View {
    var icon: String
    var title: String
    var disabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(disabled ? AppTheme.muted.opacity(0.45) : AppTheme.ink)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(disabled ? 0.10 : 0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(disabled ? Color.white.opacity(0.18) : Color.white.opacity(0.32), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(title)
    }
}

private struct DrawerContainerRow: View {
    @EnvironmentObject private var store: ContainerStore
    var container: ContainerItem

    private var isRunning: Bool {
        container.status == .running
    }

    private var isSelected: Bool {
        store.selectedContainerID == container.id
    }

    private var isBusy: Bool {
        store.isContainerBusy(container.id)
    }

    var body: some View {
        HStack(spacing: 10) {
            ContainerEffectIcon(status: container.status, isBusy: isBusy, size: 20)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(container.name)
                    .font(.system(size: 12.8, weight: .bold))
                    .foregroundStyle(AppTheme.coreInk)
                    .lineLimit(1)

                Text(container.image)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.coreMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            StatusBadge(status: container.status)
                .fixedSize()

            HStack(spacing: 6) {
                DrawerActionButton(icon: "play.fill", title: "Start", emphasized: true, disabled: isBusy || isRunning) {
                    selectContainer()
                    Task { await store.startSelectedContainer() }
                }

                DrawerActionButton(icon: "stop.fill", title: "Stop", emphasized: false, disabled: isBusy || !isRunning) {
                    selectContainer()
                    Task { await store.stopSelectedContainer() }
                }

                DrawerActionButton(icon: "arrow.clockwise", title: "Restart", emphasized: false, disabled: isBusy || !isRunning) {
                    selectContainer()
                    Task { await store.restartSelectedContainer() }
                }

                DrawerActionButton(icon: "doc.text", title: "Logs", emphasized: false, disabled: false) {
                    store.openDetail(container, tab: .logs)
                    store.setUIMode(.full)
                }
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 50)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            selectContainer()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.coreStroke)
                .frame(height: 1)
                .padding(.horizontal, 10)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        isSelected ? AppTheme.coreGlassRaised.opacity(0.90) : AppTheme.coreGlassRaised.opacity(0.50),
                        isSelected ? AppTheme.cyan.opacity(0.16) : AppTheme.coreGlass.opacity(0.38)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func selectContainer() {
        store.selectedContainerID = container.id
        store.selectedRows = [container.id]
    }
}

private struct DrawerActionButton: View {
    var icon: String
    var title: String
    var emphasized: Bool
    var disabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(disabled ? AppTheme.coreMuted.opacity(0.38) : (emphasized ? AppTheme.cyan : AppTheme.coreInk))
                .frame(width: 27, height: 27)
                .background(AppTheme.coreGlassRaised.opacity(disabled ? 0.32 : 0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(emphasized && !disabled ? AppTheme.cyan.opacity(0.28) : AppTheme.coreStroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(title)
    }
}

private struct TrafficLightButton: View {
    var color: Color
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.opacity(0.90))
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.29), lineWidth: 0.6)
                }
                .frame(width: 18, height: 18)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct DrawerListFooter: View {
    var hiddenCount: Int
    var action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(hiddenText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.coreMuted)

            Spacer()

            Button(action: action) {
                HStack(spacing: 5) {
                    Text("Open full list")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(AppTheme.blue)
            }
            .buttonStyle(.plain)
            .help("Open the full containers view")
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(AppTheme.coreGlass.opacity(0.48))
    }

    private var hiddenText: String {
        hiddenCount == 1 ? "1 more container" : "\(hiddenCount) more containers"
    }
}

private extension View {
    func drawerPanel(cornerRadius: CGFloat) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                LinearGradient(
                    colors: [
                        AppTheme.coreGlassRaised.opacity(0.74),
                        AppTheme.coreGlass.opacity(0.64)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.coreStroke, lineWidth: 1)
            }
    }
}
