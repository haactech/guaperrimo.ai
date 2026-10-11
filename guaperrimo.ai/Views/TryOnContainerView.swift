//
//  TryOnContainerView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct TryOnContainerView: View {
    @Bindable var viewModel: ConversationViewModel

    var body: some View {
        switch viewModel.tryOnState {
        case .idle:
            EmptyView()

        case .loading(let action):
            TryOnLoadingView(
                action: action,
                userImageUrl: viewModel.userImageUrl,
                onCancel: { viewModel.dismissTryOn() }
            )

        case .result(let action, let url):
            TryOnResultView(
                action: action,
                resultUrl: url,
                userImageUrl: viewModel.userImageUrl,
                onDismiss: { viewModel.dismissTryOn() }
            )

        case .error(let action, let message):
            TryOnErrorView(
                action: action,
                errorMessage: message,
                onRetry: { viewModel.retryTryOn() },
                onDismiss: { viewModel.dismissTryOn() }
            )
        }
    }
}
#endif
