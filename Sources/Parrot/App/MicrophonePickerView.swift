import SwiftUI

@MainActor
struct MicrophonePickerView: View {
    @Bindable var deviceManager: AudioDeviceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Auto-detect option
            MicrophoneRow(
                name: "Auto-detect",
                detail: defaultDeviceName,
                isSelected: deviceManager.selectedDeviceUID == nil
            ) {
                deviceManager.selectedDeviceUID = nil
            }

            // Individual devices
            ForEach(deviceManager.availableDevices) { device in
                MicrophoneRow(
                    name: device.name,
                    detail: device.transportType,
                    isSelected: deviceManager.selectedDeviceUID == device.uid
                ) {
                    deviceManager.selectedDeviceUID = device.uid
                }
            }
        }
        .onAppear {
            deviceManager.refreshDevices()
        }
    }

    private var defaultDeviceName: String {
        deviceManager.availableDevices.first(where: { $0.isDefault })?.name ?? ""
    }
}

private struct MicrophoneRow: View {
    let name: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark" : "")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 14)

                Text(name)
                    .font(.body)

                if !detail.isEmpty {
                    Text("(\(detail))")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: MenuBarStyle.rowCornerRadius)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
