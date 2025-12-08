import SwiftUI

struct ErrorOverlayView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Error card
            VStack(spacing: 24) {
                // Error icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.red)
                }
                
                // Error content
                VStack(spacing: 12) {
                    Text(LocalizedStringKey("error_overlay_title"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(error.localizedDescription)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    // Dismiss button
                    Button(action: onDismiss) {
                        Text(LocalizedStringKey("error_overlay_dismiss"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                            )
                    }
                    
                    // Retry button (if retryable)
                    if let onRetry = onRetry {
                        Button(action: onRetry) {
                            Text(LocalizedStringKey("error_overlay_retry"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue)
                                )
                        }
                    }
                }
            }
            .padding(.all, 32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ErrorOverlayView(
            error: AppError.connectionFailed(transport: "Wi-Fi Aware", details: "Connection timeout"),
            onRetry: {
                print("Retry tapped")
            },
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
}
