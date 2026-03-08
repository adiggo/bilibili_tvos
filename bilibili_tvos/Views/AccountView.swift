import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct AccountView: View {
    @State private var qrImage: Image?
    @State private var qrKey: String?
    @State private var statusMessage: String = ""
    @State private var isLoading = false
    @State private var isLoggedIn = BilibiliApiService.shared.isLoggedIn
    @State private var accountInfo: AccountInfo?
    @State private var pollTask: Task<Void, Never>?
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    private var qrSize: CGFloat {
        min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * 0.45
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Account")
                .font(.largeTitle)
                .bold()
            
            if isLoggedIn {
                if let accountInfo = accountInfo {
                    HStack(spacing: 24) {
                        CachedAsyncImage(
                            urlString: accountInfo.face,
                            targetSize: CGSize(width: 120, height: 120),
                            contentMode: .fill,
                            cornerRadius: 60,
                            placeholder: Circle().fill(Color.gray.opacity(0.2))
                        )
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(accountInfo.uname)
                                .font(.title2)
                                .bold()
                            Text("UID: \(accountInfo.mid)")
                                .foregroundColor(.secondary)
                            Text("Level: \(accountInfo.level)")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("Logged in")
                        .foregroundColor(.green)
                }
                
                Button("Log Out") {
                    BilibiliApiService.shared.logout()
                    refreshLoginState()
                }
                .buttonStyle(.card)
            } else {
                if let qrImage = qrImage {
                    qrImage
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: qrSize, height: qrSize)
                        .background(Color.white)
                        .cornerRadius(20)
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: qrSize, height: qrSize)
                        .overlay(Text("QR not generated"))
                }
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundColor(.secondary)
                }
                
                Button(isLoading ? "Generating..." : "Generate QR Code") {
                    Task { await startLogin() }
                }
                .buttonStyle(.card)
                .disabled(isLoading)
            }
        }
        .padding(60)
        .onAppear {
            refreshLoginState()
            if isLoggedIn {
                Task { await loadAccountInfo() }
            }
        }
        .onDisappear {
            pollTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: BilibiliApiService.authDidChangeNotification)) { _ in
            refreshLoginState()
            if isLoggedIn {
                Task { await loadAccountInfo() }
            } else {
                accountInfo = nil
                qrImage = nil
                qrKey = nil
            }
        }
    }
    
    private func refreshLoginState() {
        isLoggedIn = BilibiliApiService.shared.isLoggedIn
    }
    
    @MainActor
    private func loadAccountInfo() async {
        do {
            accountInfo = try await BilibiliApiService.shared.fetchAccountInfo()
        } catch {
            statusMessage = "Failed to load account info: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func startLogin() async {
        isLoading = true
        statusMessage = "Requesting QR code..."
        qrImage = nil
        qrKey = nil
        pollTask?.cancel()
        
        do {
            let qrData = try await BilibiliApiService.shared.generateQrCode()
            qrKey = qrData.qrcodeKey
            qrImage = generateQrImage(from: qrData.url)
            statusMessage = "Scan with Bilibili app to log in"
            isLoading = false
            startPolling()
        } catch {
            statusMessage = "QR generation failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func startPolling() {
        guard let key = qrKey else { return }
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                do {
                    let poll = try await BilibiliApiService.shared.pollQrCode(key: key)
                    await MainActor.run {
                        updateStatus(with: poll)
                    }
                    if poll.code == 0, let redirect = poll.url {
                        try await BilibiliApiService.shared.completeQrLogin(redirectUrl: redirect)
                        await MainActor.run {
                            refreshLoginState()
                            statusMessage = "Login successful"
                        }
                        await loadAccountInfo()
                        return
                    }
                    if poll.code == 86038 {
                        await MainActor.run { statusMessage = "QR expired. Generate a new one." }
                        return
                    }
                } catch {
                    await MainActor.run { statusMessage = "Polling error: \(error.localizedDescription)" }
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
    
    private func updateStatus(with poll: QrPollData) {
        switch poll.code {
        case 86101:
            statusMessage = "Waiting for scan"
        case 86090:
            statusMessage = "Scanned. Confirm on phone"
        case 0:
            statusMessage = "Confirmed. Finalizing login..."
        default:
            statusMessage = poll.message ?? "Waiting..."
        }
    }
    
    private func generateQrImage(from string: String) -> Image? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        if let outputImage = filter.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return Image(decorative: cgImage, scale: 1, orientation: .up)
        }
        return nil
    }
}
