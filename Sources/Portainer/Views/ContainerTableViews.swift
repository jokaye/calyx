import SwiftUI

struct ContainerTableHeader: View {
    var compact: Bool
    var dark = false

    var body: some View {
        HStack(spacing: 0) {
            if !compact {
                tableText("", width: 34, alignment: .leading)
            }
            tableText("Name", width: compact ? 150 : 150, alignment: .leading)
            tableText("Image", width: compact ? 170 : 190, alignment: .leading)
            tableText("Status", width: compact ? 120 : 112, alignment: .leading)
            tableText("CPU", width: compact ? 92 : 78, alignment: .leading)
            tableText("Memory", width: compact ? 110 : 112, alignment: .leading)
            tableText("Uptime", width: compact ? 112 : 112, alignment: .leading)
            if !compact {
                tableText("IP Address", width: 138, alignment: .leading)
            }
            tableText("Actions", width: compact ? 90 : 104, alignment: .center)
        }
        .frame(height: 36)
        .foregroundStyle(dark ? AppTheme.coreMuted : AppTheme.ink.opacity(0.78))
        .font(.system(size: 12, weight: .medium))
    }

    private func tableText(_ value: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(value)
            .frame(width: width, alignment: alignment)
    }
}

struct ContainerTableRow: View {
    var container: ContainerItem
    var compact: Bool
    var dark = false
    var isSelected = false
    var isBusy = false
    var onOpen: () -> Void
    var onToggleSelection: (() -> Void)?
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    var onRestart: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            if !compact {
                Button {
                    onToggleSelection?()
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? AppTheme.blue : mutedColor.opacity(0.7))
                        .frame(width: 34, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(onToggleSelection == nil)
                .help(isSelected ? "Clear selection" : "Select container")
            }

            HStack(spacing: 0) {
                nameCell
                rowText(container.image, width: compact ? 170 : 190)
                StatusBadge(status: container.status)
                    .frame(width: compact ? 120 : 112, alignment: .leading)
                rowText(String(format: "%.1f%%", container.cpuPercent), width: compact ? 92 : 78)
                rowText(ByteFormatter.memory(container.memoryBytes), width: compact ? 110 : 112)
                rowText(container.uptime, width: compact ? 112 : 112)
                if !compact {
                    rowText(container.ipAddress, width: 138)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            HStack(spacing: compact ? 5 : 7) {
                rowActionButton(
                    systemName: "play.fill",
                    title: "Start",
                    disabled: isBusy || container.status == .running,
                    action: onStart
                )
                rowActionButton(
                    systemName: "stop.fill",
                    title: "Stop",
                    disabled: isBusy || container.status != .running,
                    action: onStop
                )
                rowActionButton(
                    systemName: "arrow.clockwise",
                    title: "Restart",
                    disabled: isBusy || container.status != .running,
                    action: onRestart
                )
            }
            .frame(width: compact ? 90 : 104)
        }
        .frame(height: compact ? 42 : 54)
        .background(selectedBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(separatorColor)
                .frame(height: 1)
        }
    }

    private var textColor: Color {
        dark ? AppTheme.coreInk : AppTheme.ink
    }

    private var mutedColor: Color {
        dark ? AppTheme.coreMuted : AppTheme.muted
    }

    private var separatorColor: Color {
        dark ? AppTheme.coreStroke : AppTheme.separator
    }

    private var selectedBackground: Color {
        if isSelected {
            return dark ? AppTheme.coreGlassRaised.opacity(0.86) : AppTheme.surfaceSelected.opacity(0.78)
        }
        return Color.clear
    }

    private func rowText(_ value: String, width: CGFloat, weight: Font.Weight = .medium) -> some View {
        Text(value)
            .lineLimit(1)
            .font(.system(size: 12.5, weight: weight))
            .foregroundStyle(textColor)
            .frame(width: width, alignment: .leading)
    }

    private var nameCell: some View {
        let iconSize: CGFloat = compact ? 18 : 20

        return HStack(spacing: 8) {
            ContainerEffectIcon(status: container.status, isBusy: isBusy, size: iconSize)
                .frame(width: iconSize, height: iconSize)
            Text(container.name)
                .lineLimit(1)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(textColor)
            Spacer(minLength: 0)
        }
        .frame(width: compact ? 150 : 150, alignment: .leading)
    }

    private func rowActionButton(systemName: String, title: String, disabled: Bool, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
                .foregroundStyle(disabled || action == nil ? mutedColor.opacity(0.55) : textColor)
                .frame(width: compact ? 22 : 26, height: compact ? 24 : 28)
                .background(actionBackground(disabled: disabled || action == nil), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(dark ? AppTheme.coreStroke : AppTheme.panelStroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled || action == nil)
        .help(title)
    }

    private func actionBackground(disabled: Bool) -> Color {
        if dark {
            return AppTheme.coreGlassRaised.opacity(disabled ? 0.34 : 0.70)
        }
        return Color.white.opacity(disabled ? 0.12 : 0.24)
    }
}

struct ContainersListView: View {
    @EnvironmentObject private var store: ContainerStore
    @State private var pendingRemoveContainer: ContainerItem?
    @State private var removeConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                Text("Containers")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
            }

            HStack(spacing: 16) {
                SearchField(placeholder: "Search containers...", text: $store.searchQuery)
                    .frame(width: 304)

                Spacer()

                ActionButton(title: store.isRefreshing ? "Refreshing" : "Refresh", icon: "arrow.clockwise", tint: AppTheme.ink, disabled: store.isRefreshing) {
                    Task { await store.refresh() }
                }
                ActionButton(title: "Run", icon: "plus", tint: AppTheme.blue, filled: true) {
                    store.showRunContainer()
                }
                ActionButton(title: "Start", icon: "play", tint: AppTheme.ink, disabled: !canStartSelection) {
                    startToolbarSelection()
                }
                ActionButton(title: "Stop", icon: "stop", tint: AppTheme.muted, disabled: !canStopSelection) {
                    stopToolbarSelection()
                }
                ActionButton(title: "Restart", icon: "arrow.clockwise", tint: AppTheme.ink, disabled: !canRestartSelection) {
                    restartToolbarSelection()
                }
                ActionButton(title: "Remove", icon: "trash", tint: AppTheme.red, filled: true, disabled: selectedActionContainer == nil) {
                    removeToolbarSelection()
                }
            }

            CoreGlassCard(cornerRadius: 10, padding: 0) {
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ContainerTableHeader(compact: false, dark: true)
                                .padding(.horizontal, 18)
                                .padding(.top, 14)

                            if !store.filteredContainers.isEmpty {
                                ForEach(store.filteredContainers) { container in
                                    ContainerTableRow(
                                        container: container,
                                        compact: false,
                                        dark: true,
                                        isSelected: store.selectedRows.contains(container.id),
                                        isBusy: store.isContainerBusy(container.id)
                                    ) {
                                        store.openDetail(container)
                                    } onToggleSelection: {
                                        toggleSelection(container)
                                    } onStart: {
                                        start(container)
                                    } onStop: {
                                        stop(container)
                                    } onRestart: {
                                        restart(container)
                                    }
                                    .padding(.horizontal, 18)
                                }
                            }
                        }
                        .frame(minWidth: 1_066, alignment: .leading)
                    }

                    if store.filteredContainers.isEmpty {
                        EmptyContainersView(
                            compact: false,
                            dark: true,
                            title: emptyTitle,
                            message: emptyMessage,
                            actionTitle: emptyActionTitle,
                            action: emptyAction
                        )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Text(showingText)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AppTheme.coreMuted)
                        Spacer()
                        if let selectedActionContainer {
                            Text("Selected: \(selectedActionContainer.name)")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(AppTheme.coreInk)
                        }
                    }
                    .padding(.horizontal, 22)
                    .frame(height: 68)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(AppTheme.coreStroke)
                            .frame(height: 1)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .alert("Remove container?", isPresented: $removeConfirmationPresented, presenting: pendingRemoveContainer) { container in
                Button("Remove", role: .destructive) {
                    confirmRemove(container)
                }
                Button("Cancel", role: .cancel) {
                    pendingRemoveContainer = nil
                }
            } message: { container in
                Text("This will remove \(container.name) with the Apple container CLI.")
            }
        }
    }

    private var showingText: String {
        if store.containers.isEmpty {
            return "No containers"
        }
        if store.filteredContainers.isEmpty {
            return "No matching containers"
        }
        if searchQuery.isEmpty {
            return "Showing \(store.filteredContainers.count) containers"
        }
        return "Showing \(store.filteredContainers.count) of \(store.containers.count) containers"
    }

    private var searchQuery: String {
        store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedActionContainer: ContainerItem? {
        guard store.selectedRows.count == 1, let id = store.selectedRows.first else { return nil }
        return store.containers.first { $0.id == id }
    }

    private var canStartSelection: Bool {
        guard let selectedActionContainer else { return false }
        return selectedActionContainer.status != .running
    }

    private var canStopSelection: Bool {
        selectedActionContainer?.status == .running
    }

    private var canRestartSelection: Bool {
        selectedActionContainer?.status == .running
    }

    private var emptyTitle: String {
        searchQuery.isEmpty ? "No containers" : "No matching containers"
    }

    private var emptyMessage: String {
        if searchQuery.isEmpty {
            return "Run a container from the toolbar or create one with the Apple container CLI, then refresh."
        }
        return "No container name, image, status, or IP address matches the current search."
    }

    private var emptyActionTitle: String? {
        searchQuery.isEmpty ? "Run Container" : "Clear Search"
    }

    private var emptyAction: (() -> Void)? {
        if searchQuery.isEmpty {
            return { store.showRunContainer() }
        }
        return { store.searchQuery = "" }
    }

    private func toggleSelection(_ container: ContainerItem) {
        if store.selectedRows.contains(container.id) {
            store.selectedRows.removeAll()
        } else {
            store.selectedRows = [container.id]
        }
        store.selectedContainerID = nil
    }

    private func startToolbarSelection() {
        guard selectToolbarTarget() else { return }
        Task { await store.startSelectedContainer() }
    }

    private func stopToolbarSelection() {
        guard selectToolbarTarget() else { return }
        Task { await store.stopSelectedContainer() }
    }

    private func restartToolbarSelection() {
        guard selectToolbarTarget() else { return }
        Task { await store.restartSelectedContainer() }
    }

    private func removeToolbarSelection() {
        guard let selectedActionContainer else { return }
        pendingRemoveContainer = selectedActionContainer
        removeConfirmationPresented = true
    }

    private func selectToolbarTarget() -> Bool {
        guard let selectedActionContainer else { return false }
        store.selectedContainerID = selectedActionContainer.id
        return true
    }

    private func start(_ container: ContainerItem) {
        target(container)
        Task { await store.startSelectedContainer() }
    }

    private func stop(_ container: ContainerItem) {
        target(container)
        Task { await store.stopSelectedContainer() }
    }

    private func restart(_ container: ContainerItem) {
        target(container)
        Task { await store.restartSelectedContainer() }
    }

    private func target(_ container: ContainerItem) {
        store.selectedContainerID = container.id
        store.selectedRows.removeAll()
    }

    private func confirmRemove(_ container: ContainerItem) {
        store.selectedContainerID = container.id
        store.selectedRows = [container.id]
        pendingRemoveContainer = nil
        Task { await store.deleteSelectedContainer() }
    }
}

struct EmptyContainersView: View {
    var compact: Bool
    var dark = false
    var title = "No containers"
    var message = "Run `container run --name web-app -d nginx:alpine` or create a container from the CLI, then refresh."
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: compact ? 22 : 30, weight: .semibold))
                .foregroundStyle(AppTheme.blue.opacity(0.72))
            Text(title)
                .font(.system(size: compact ? 13 : 17, weight: .bold))
                .foregroundStyle(dark ? AppTheme.coreInk : AppTheme.ink)
            Text(message)
                .font(.system(size: compact ? 11 : 12, weight: .medium))
                .foregroundStyle(dark ? AppTheme.coreMuted : AppTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: compact ? 320 : 460)
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 7) {
                        Image(systemName: actionTitle == "Clear Search" ? "xmark" : "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text(actionTitle)
                            .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.blue)
                    .padding(.horizontal, compact ? 10 : 12)
                    .frame(height: compact ? 28 : 32)
                    .background((dark ? AppTheme.coreGlassRaised : AppTheme.surfaceRaised).opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(compact ? 12 : 24)
    }
}
