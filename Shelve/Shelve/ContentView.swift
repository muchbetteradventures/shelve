import SwiftUI
import SafariServices

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.and.arrow.down.fill")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundStyle(.blue)

            Text("Shelve")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Save pages from Safari to your local API. Capture URLs, selected text, tags, and notes.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 60)

            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: "1", text: "Enable the extension in Safari Settings > Extensions")
                instructionRow(number: "2", text: "Start your API server (default: http://localhost:9876)")
                instructionRow(number: "3", text: "Click the Shelve icon in Safari's toolbar to save pages")
                instructionRow(number: "4", text: "Configure the API endpoint in the extension settings")
            }
            .padding(.horizontal, 40)

            Button("Open Safari Extension Preferences") {
                SFSafariApplication.showPreferencesForExtension(withIdentifier: "com.shelve-app.app.extension") { error in
                    if let error = error {
                        print("Error opening preferences: \(error)")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
        .frame(minWidth: 480, minHeight: 420)
        .padding(30)
    }

    func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.blue))
            Text(text)
                .font(.callout)
        }
    }
}
