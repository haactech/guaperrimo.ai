//
//  CameraPermissionView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct CameraPermissionView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.7))

                Text(String(localized: "camera_permission_title"))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(String(localized: "camera_permission_message"))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(String(localized: "open_settings"))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
                .padding(.top, 8)
            }
        }
    }
}
#endif
