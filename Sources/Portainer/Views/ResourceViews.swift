import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImagesView: View {
    @EnvironmentObject private var store: ContainerStore
    @State private var searchQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            resourceHeader(
                title: "Images",
                subtitle: "\(filteredImages.count) image\(filteredImages.count == 1 ? "" : "s")",
                refreshAction: { Task { await store.loadResources(for: .images) } }
            )

            SearchField(placeholder: "Search images...", text: $searchQuery)
                .frame(width: 320)

            CoreGlassCard(cornerRadius: 10, padding: 0) {
                VStack(spacing: 0) {
                    ResourceTableHeader(columns: imageColumns)
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                    if filteredImages.isEmpty {
                        ResourceEmptyState(
                            icon: "cube.box",
                            title: store.images.isEmpty ? "No images" : "No matching images",
                            message: store.images.isEmpty ? "Pull or build images with the Apple container CLI, then refresh." : "No image name, digest, media type, or platform matches the current search."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredImages) { image in
                                    ImageResourceRow(image: image)
                                        .padding(.horizontal, 18)
                                }
                            }
                            .frame(minWidth: 1_000, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .task {
            await store.loadResources(for: .images)
        }
    }

    private var filteredImages: [ImageItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.images }
        return store.images.filter {
            $0.name.lowercased().contains(query)
                || $0.digest.lowercased().contains(query)
                || $0.mediaType.lowercased().contains(query)
                || $0.platforms.lowercased().contains(query)
        }
    }

    private var imageColumns: [ResourceColumn] {
        [
            ResourceColumn(title: "Name", width: 310),
            ResourceColumn(title: "Digest", width: 300),
            ResourceColumn(title: "Platform", width: 170),
            ResourceColumn(title: "Size", width: 110),
            ResourceColumn(title: "Created", width: 190)
        ]
    }
}

struct VolumesView: View {
    @EnvironmentObject private var store: ContainerStore
    @State private var searchQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            resourceHeader(
                title: "Volumes",
                subtitle: "\(filteredVolumes.count) volume\(filteredVolumes.count == 1 ? "" : "s")",
                refreshAction: { Task { await store.loadResources(for: .volumes) } }
            )

            SearchField(placeholder: "Search volumes...", text: $searchQuery)
                .frame(width: 320)

            CoreGlassCard(cornerRadius: 10, padding: 0) {
                VStack(spacing: 0) {
                    ResourceTableHeader(columns: volumeColumns)
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                    if filteredVolumes.isEmpty {
                        ResourceEmptyState(
                            icon: "externaldrive",
                            title: store.volumes.isEmpty ? "No volumes" : "No matching volumes",
                            message: store.volumes.isEmpty ? "Create volumes with the Apple container CLI, then refresh." : "No volume name matches the current search."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredVolumes) { volume in
                                VolumeResourceRow(volume: volume)
                                    .padding(.horizontal, 18)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .task {
            await store.loadResources(for: .volumes)
        }
    }

    private var filteredVolumes: [VolumeItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.volumes }
        return store.volumes.filter { $0.name.lowercased().contains(query) }
    }

    private var volumeColumns: [ResourceColumn] {
        [
            ResourceColumn(title: "Name", width: 360),
            ResourceColumn(title: "Size", width: 150),
            ResourceColumn(title: "Containers", width: 140),
            ResourceColumn(title: "Created", width: 240)
        ]
    }
}

struct NetworksView: View {
    @EnvironmentObject private var store: ContainerStore
    @State private var searchQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            resourceHeader(
                title: "Networks",
                subtitle: "\(filteredNetworks.count) attachment\(filteredNetworks.count == 1 ? "" : "s")",
                refreshAction: { Task { await store.loadResources(for: .networks) } }
            )

            SearchField(placeholder: "Search network attachments...", text: $searchQuery)
                .frame(width: 340)

            CoreGlassCard(cornerRadius: 10, padding: 0) {
                VStack(spacing: 0) {
                    ResourceTableHeader(columns: networkColumns)
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                    if filteredNetworks.isEmpty {
                        ResourceEmptyState(
                            icon: "point.3.connected.trianglepath.dotted",
                            title: store.networks.isEmpty ? "No network attachments" : "No matching attachments",
                            message: store.networks.isEmpty ? "No configured container network attachments were found." : "No network, container, address, gateway, or hostname matches the current search."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredNetworks) { network in
                                    NetworkResourceRow(network: network)
                                        .padding(.horizontal, 18)
                                }
                            }
                            .frame(minWidth: 1_110, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .task {
            await store.loadResources(for: .networks)
        }
    }

    private var filteredNetworks: [NetworkAttachmentItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.networks }
        return store.networks.filter {
            $0.networkName.lowercased().contains(query)
                || $0.containerName.lowercased().contains(query)
                || $0.containerID.lowercased().contains(query)
                || $0.address.lowercased().contains(query)
                || $0.gateway.lowercased().contains(query)
                || $0.hostname.lowercased().contains(query)
                || $0.status.rawValue.lowercased().contains(query)
        }
    }

    private var networkColumns: [ResourceColumn] {
        [
            ResourceColumn(title: "Network", width: 170),
            ResourceColumn(title: "Container", width: 260),
            ResourceColumn(title: "Status", width: 110),
            ResourceColumn(title: "Address", width: 170),
            ResourceColumn(title: "Gateway", width: 160),
            ResourceColumn(title: "Hostname", width: 260),
            ResourceColumn(title: "MTU", width: 80)
        ]
    }
}

struct ConfigsView: View {
    @EnvironmentObject private var store: ContainerStore
    @State private var searchQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            resourceHeader(
                title: "Configs",
                subtitle: "\(filteredConfigs.count) derived entr\(filteredConfigs.count == 1 ? "y" : "ies")",
                refreshAction: { Task { await store.loadResources(for: .configs) } }
            )

            SearchField(placeholder: "Search configs...", text: $searchQuery)
                .frame(width: 320)

            CoreGlassCard(cornerRadius: 10, padding: 0) {
                VStack(spacing: 0) {
                    ResourceTableHeader(columns: configColumns)
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                    if filteredConfigs.isEmpty {
                        ResourceEmptyState(
                            icon: "doc.text",
                            title: store.configs.isEmpty ? "No derived configs" : "No matching configs",
                            message: store.configs.isEmpty ? "No non-sensitive environment variables or labels were found." : "No config key, value, source, or container matches the current search."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredConfigs) { config in
                                    ConfigResourceRow(config: config)
                                        .padding(.horizontal, 18)
                                }
                            }
                            .frame(minWidth: 1_030, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .task {
            await store.loadResources(for: .configs)
        }
    }

    private var filteredConfigs: [DerivedConfigItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.configs }
        return store.configs.filter {
            $0.key.lowercased().contains(query)
                || $0.value.lowercased().contains(query)
                || $0.source.rawValue.lowercased().contains(query)
                || $0.containerName.lowercased().contains(query)
        }
    }

    private var configColumns: [ResourceColumn] {
        [
            ResourceColumn(title: "Key", width: 280),
            ResourceColumn(title: "Value", width: 360),
            ResourceColumn(title: "Source", width: 140),
            ResourceColumn(title: "Container", width: 250)
        ]
    }
}

struct SecretsView: View {
    @EnvironmentObject private var store: ContainerStore
    @State private var searchQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            resourceHeader(
                title: "Secrets",
                subtitle: "\(filteredSecrets.count) masked reference\(filteredSecrets.count == 1 ? "" : "s")",
                refreshAction: { Task { await store.loadResources(for: .secrets) } }
            )

            SearchField(placeholder: "Search secret references...", text: $searchQuery)
                .frame(width: 340)

            CoreGlassCard(cornerRadius: 10, padding: 0) {
                VStack(spacing: 0) {
                    ResourceTableHeader(columns: secretColumns)
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                    if filteredSecrets.isEmpty {
                        ResourceEmptyState(
                            icon: "lock.shield",
                            title: store.secrets.isEmpty ? "No secret references" : "No matching secrets",
                            message: store.secrets.isEmpty ? "No secret-like environment variable or label names were found." : "No secret key, source, or container matches the current search."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredSecrets) { secret in
                                SecretResourceRow(secret: secret)
                                    .padding(.horizontal, 18)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .task {
            await store.loadResources(for: .secrets)
        }
    }

    private var filteredSecrets: [DerivedSecretReference] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.secrets }
        return store.secrets.filter {
            $0.key.lowercased().contains(query)
                || $0.source.rawValue.lowercased().contains(query)
                || $0.containerName.lowercased().contains(query)
        }
    }

    private var secretColumns: [ResourceColumn] {
        [
            ResourceColumn(title: "Key", width: 360),
            ResourceColumn(title: "Value", width: 180),
            ResourceColumn(title: "Source", width: 150),
            ResourceColumn(title: "Container", width: 290)
        ]
    }
}

struct EventsView: View {
    @EnvironmentObject private var store: ContainerStore
    @State private var searchQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Events")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("\(filteredEvents.count) runtime log line\(filteredEvents.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Picker("", selection: $store.systemEventWindow) {
                    Text("5m").tag("5m")
                    Text("30m").tag("30m")
                    Text("1h").tag("1h")
                    Text("1d").tag("1d")
                }
                .labelsHidden()
                .frame(width: 96)
                ActionButton(title: "Refresh", icon: "arrow.clockwise", tint: AppTheme.ink) {
                    Task { await store.refreshEvents() }
                }
            }

            SearchField(placeholder: "Search runtime activity...", text: $searchQuery)
                .frame(width: 360)

            CoreGlassCard(cornerRadius: 10, padding: 0) {
                VStack(spacing: 0) {
                    ResourceTableHeader(columns: eventColumns)
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                    if filteredEvents.isEmpty {
                        ResourceEmptyState(
                            icon: "dot.radiowaves.left.and.right",
                            title: store.systemEvents.isEmpty ? "No runtime activity" : "No matching activity",
                            message: store.systemEvents.isEmpty ? "No system log lines were returned for the selected window." : "No timestamp, level, service, or message matches the current search."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredEvents) { event in
                                    EventResourceRow(event: event)
                                        .padding(.horizontal, 18)
                                }
                            }
                            .frame(minWidth: 1_030, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .task {
            await store.loadResources(for: .events)
        }
        .onChange(of: store.systemEventWindow) {
            Task { await store.refreshEvents() }
        }
    }

    private var filteredEvents: [SystemEventLine] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.systemEvents }
        return store.systemEvents.filter {
            $0.timestamp.lowercased().contains(query)
                || $0.level.lowercased().contains(query)
                || $0.service.lowercased().contains(query)
                || $0.message.lowercased().contains(query)
        }
    }

    private var eventColumns: [ResourceColumn] {
        [
            ResourceColumn(title: "Timestamp", width: 220),
            ResourceColumn(title: "Level", width: 100),
            ResourceColumn(title: "Service", width: 180),
            ResourceColumn(title: "Message", width: 530)
        ]
    }
}

struct ComposeView: View {
    @EnvironmentObject private var store: ContainerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Compose")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(composeSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                ActionButton(title: "Open File", icon: "folder", tint: AppTheme.blue) {
                    chooseComposeFile()
                }
                ActionButton(title: "Refresh", icon: "arrow.clockwise", tint: AppTheme.ink) {
                    Task { await store.loadResources(for: .compose) }
                }
                ActionButton(title: "Up", icon: "play", tint: AppTheme.blue, disabled: true) {}
                ActionButton(title: "Down", icon: "stop", tint: AppTheme.red, disabled: true) {}
            }

            HStack(spacing: 16) {
                ComposeStatusCard(preview: store.composePreview, support: store.composeSupport)
                    .frame(width: 320)

                CoreGlassCard(cornerRadius: 10, padding: 0) {
                    if store.composePreview.content.isEmpty {
                        ResourceEmptyState(
                            icon: "square.stack.3d.up",
                            title: "No compose file selected",
                            message: "Open a compose.yaml, compose.yml, or docker-compose.yml file to preview it."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView([.vertical, .horizontal]) {
                            Text(store.composePreview.content)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.coreInk)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .task {
            await store.loadResources(for: .compose)
        }
    }

    private var composeSubtitle: String {
        if store.composePreview.name.isEmpty {
            return store.composeSupport.available ? "Plugin detected" : "Preview mode"
        }
        return store.composePreview.name
    }

    private func chooseComposeFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "yaml") ?? .plainText,
            UTType(filenameExtension: "yml") ?? .plainText
        ]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            store.loadComposeFile(at: url)
        }
    }
}

private func resourceHeader(title: String, subtitle: String, refreshAction: @escaping () -> Void) -> some View {
    HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.muted)
        }
        Spacer()
        ActionButton(title: "Refresh", icon: "arrow.clockwise", tint: AppTheme.ink, action: refreshAction)
    }
}

private struct ResourceColumn {
    var title: String
    var width: CGFloat
}

private struct ResourceTableHeader: View {
    var columns: [ResourceColumn]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.title) { column in
                Text(column.title)
                    .frame(width: column.width, alignment: .leading)
            }
        }
        .frame(height: 36, alignment: .leading)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppTheme.coreMuted)
    }
}

private struct ImageResourceRow: View {
    var image: ImageItem

    var body: some View {
        HStack(spacing: 0) {
            resourceText(image.name, width: 310, weight: .semibold)
            resourceText(shortDigest(image.digest), width: 300)
            resourceText(image.platforms, width: 170)
            resourceText(ByteFormatter.compact(image.sizeBytes), width: 110)
            resourceText(image.createdAt, width: 190)
        }
        .frame(height: 54)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.coreStroke)
                .frame(height: 1)
        }
    }

    private func shortDigest(_ digest: String) -> String {
        guard digest.count > 24 else { return digest }
        return "\(digest.prefix(21))..."
    }
}

private struct VolumeResourceRow: View {
    var volume: VolumeItem

    var body: some View {
        HStack(spacing: 0) {
            resourceText(volume.name, width: 360, weight: .semibold)
            resourceText(ByteFormatter.compact(volume.sizeBytes), width: 150)
            resourceText("\(volume.containerCount)", width: 140)
            resourceText(volume.createdAt, width: 240)
        }
        .frame(height: 54)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.coreStroke)
                .frame(height: 1)
        }
    }
}

private struct NetworkResourceRow: View {
    var network: NetworkAttachmentItem

    var body: some View {
        HStack(spacing: 0) {
            resourceText(network.networkName, width: 170, weight: .semibold)
            resourceText(network.containerName, width: 260)
            resourceText(network.status.rawValue, width: 110)
            resourceText(network.address, width: 170)
            resourceText(network.gateway, width: 160)
            resourceText(network.hostname, width: 260)
            resourceText(network.mtu, width: 80)
        }
        .frame(height: 54)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.coreStroke)
                .frame(height: 1)
        }
    }
}

private struct ConfigResourceRow: View {
    var config: DerivedConfigItem

    var body: some View {
        HStack(spacing: 0) {
            resourceText(config.key, width: 280, weight: .semibold)
            resourceText(config.value.isEmpty ? "-" : config.value, width: 360)
            resourceText(config.source.rawValue, width: 140)
            resourceText(config.containerName, width: 250)
        }
        .frame(height: 54)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.coreStroke)
                .frame(height: 1)
        }
    }
}

private struct SecretResourceRow: View {
    var secret: DerivedSecretReference

    var body: some View {
        HStack(spacing: 0) {
            resourceText(secret.key, width: 360, weight: .semibold)
            resourceText("Masked", width: 180)
            resourceText(secret.source.rawValue, width: 150)
            resourceText(secret.containerName, width: 290)
        }
        .frame(height: 54)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.coreStroke)
                .frame(height: 1)
        }
    }
}

private struct EventResourceRow: View {
    var event: SystemEventLine

    var body: some View {
        HStack(spacing: 0) {
            resourceText(event.timestamp, width: 220)
            Text(event.level)
                .lineLimit(1)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(eventTint)
                .frame(width: 100, alignment: .leading)
            resourceText(event.service, width: 180)
            resourceText(event.message, width: 530)
        }
        .frame(height: 54)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.coreStroke)
                .frame(height: 1)
        }
    }

    private var eventTint: Color {
        switch event.level {
        case "ERROR", "ERR", "FAULT":
            AppTheme.red
        case "WARN", "WARNING":
            Color(hex: 0xFFD166)
        case "INFO":
            AppTheme.cyan
        default:
            AppTheme.coreMuted
        }
    }
}

private struct ComposeStatusCard: View {
    var preview: ComposeFilePreview
    var support: ComposeSupportStatus

    var body: some View {
        CoreGlassCard(cornerRadius: 10, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Runtime")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.coreInk)
                    Text(support.available ? "Plugin available" : "Plugin unavailable")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(support.available ? AppTheme.cyan : Color(hex: 0xFFD166))
                    Text(support.message)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(AppTheme.coreMuted)
                        .lineLimit(6)
                }

                Divider()
                    .overlay(AppTheme.coreStroke)

                VStack(alignment: .leading, spacing: 8) {
                    Text("File")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.coreInk)
                    Text(preview.name.isEmpty ? "-" : preview.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.coreInk)
                        .lineLimit(2)
                    Text(preview.path.isEmpty ? "-" : preview.path)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(AppTheme.coreMuted)
                        .lineLimit(3)
                }

                Divider()
                    .overlay(AppTheme.coreStroke)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Services")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.coreInk)
                    Text(preview.detectedServices.isEmpty ? "-" : preview.detectedServices.joined(separator: ", "))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.coreMuted)
                        .lineLimit(4)
                }

                if !preview.issues.isEmpty {
                    Divider()
                        .overlay(AppTheme.coreStroke)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(preview.issues, id: \.self) { issue in
                            Text(issue)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Color(hex: 0xFFD166))
                                .lineLimit(3)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private func resourceText(_ value: String, width: CGFloat, weight: Font.Weight = .medium) -> some View {
    Text(value)
        .lineLimit(1)
        .font(.system(size: 12.5, weight: weight))
        .foregroundStyle(AppTheme.coreInk)
        .frame(width: width, alignment: .leading)
}

private struct ResourceEmptyState: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppTheme.blue.opacity(0.80))
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.coreInk)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.coreMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .padding(24)
    }
}
