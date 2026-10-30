import SwiftUI

extension View {
    func refreshErrorAlert(
        _ error: AppError?,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(RefreshErrorAlert(error: error, onDismiss: onDismiss))
    }
}

private struct RefreshErrorAlert: ViewModifier {
    let error: AppError?
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Не удалось обновить",
            isPresented: Binding(
                get: { error != nil },
                set: { isPresented in
                    if !isPresented {
                        onDismiss()
                    }
                }
            ),
            presenting: error
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text("\(error.title). На экране остались последние загруженные данные.")
        }
    }
}
