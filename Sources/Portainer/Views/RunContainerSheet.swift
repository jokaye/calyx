import SwiftUI

struct RunContainerSheet: View {
    @EnvironmentObject private var store: ContainerStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var image = ""
    @State private var arguments = ""
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run Container")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("Runs `container run -d` and refreshes the list when it completes.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                labeledField("Name", text: $name, placeholder: "web-app")
                labeledField("Image", text: $image, placeholder: "nginx:alpine")
                labeledField("Arguments", text: $arguments, placeholder: "optional command arguments")
            }

            if let issue = store.operationIssue {
                RuntimeIssueBanner(issue: issue)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 84, height: 36)
                .background(AppTheme.surfaceRaised.opacity(0.74), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Button {
                    Task { await run() }
                } label: {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Run")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: 0x061019))
                .frame(width: 96, height: 36)
                .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .disabled(isRunning || image.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(isRunning || image.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.62 : 1)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(AppBackground())
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(AppTheme.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(AppTheme.panelStroke, lineWidth: 1)
                }
        }
    }

    private func run() async {
        isRunning = true
        defer { isRunning = false }
        let request = RunContainerRequest(
            name: name,
            image: image,
            arguments: arguments.split(separator: " ").map(String.init)
        )
        if await store.runContainer(request) {
            dismiss()
        }
    }
}
