//
//  CameraPermissionView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct CameraPermissionView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 60

    var body: some View {
        ZStack {
            TexturedBackground()

            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(DS.textSecondary)

                Text(String(localized: "camera_permission_title"))
                    .font(DS.Font.display)
                    .foregroundStyle(DS.textPrimary)
                    .multilineTextAlignment(.center)

                Text(String(localized: "camera_permission_message"))
                    .font(.body)
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                PrimaryButton(title: String(localized: "open_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
        }
    }
}
#endif
