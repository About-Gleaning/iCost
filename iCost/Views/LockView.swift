import SwiftUI
import LocalAuthentication

struct LockView: View {
    var onUnlocked: () -> Void
    @State private var errorText: String?
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock")
                .font(.system(size: 48))
            Button("使用面容/指纹解锁") { authenticateBiometrics() }
            Button("使用系统密码解锁") { authenticateDevice() }
            if let e = errorText { Text(e).foregroundStyle(.red) }
        }
    }
    private func authenticateBiometrics() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "解锁 iCost") { success, evalError in
                DispatchQueue.main.async {
                    if success { onUnlocked() } else { errorText = "解锁失败" }
                }
            }
        } else {
            errorText = "设备不支持生物识别"
        }
    }

    private func authenticateDevice() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁 iCost") { success, evalError in
                DispatchQueue.main.async {
                    if success { onUnlocked() } else { errorText = "解锁失败" }
                }
            }
        } else {
            errorText = "设备不支持系统密码解锁"
        }
    }
}
