//
//  AboutView.swift
//  A6Cutter
//
//  Created by Mario Vejlupek on 02.10.2025.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // App icon placeholder
            Image(systemName: "scissors")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("A6Cutter")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Version:")
                        .fontWeight(.semibold)
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build:")
                        .fontWeight(.semibold)
                    Text(buildNumber)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Git Hash:")
                        .fontWeight(.semibold)
                    Text(gitHash)
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            Divider()
                .padding(.horizontal, 40)
            
            ScrollView {
                Text(releaseNotes)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 40)
            }
            .frame(maxHeight: 300)
            
            Button("Close") {
                // Close the About window using SwiftUI dismiss
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
        .frame(width: 500, height: 600)
        .padding(30)
    }
    
    // MARK: - Version and Build Info
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            // Remove 'v' prefix if present for consistent display
            return version.hasPrefix("v") ? String(version.dropFirst()) : version
        }
        return "Deve"
    }
    
    private var buildNumber: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            // For local builds, CFBundleVersion is git commit hash (7 chars)
            // For GitHub Actions builds, it's a build number
            // Check if it looks like a git hash (7 chars, alphanumeric)
            if build.count == 7 && build.allSatisfy({ $0.isLetter || $0.isNumber }) {
                return build // Local build - git hash
            } else {
                return build // GitHub Actions build - build number
            }
        }
        return "dev"
    }
    
    private var gitHash: String {
        if let hash = Bundle.main.infoDictionary?["GitHash"] as? String {
            // Show first 7 characters of git hash for readability
            return String(hash.prefix(7))
        }
        return "dev"
    }
    
    private var releaseNotes: String {
        """
        ### What's New in \(appVersion)
        
        - PDF cutting into A6-sized tiles
        - Customizable settings with live preview
        - Page rotation and skipping
        - Preset management (Default, FedEx)
        - Direct printing integration
        - Keyboard shortcuts (CMD+O, CMD+SHIFT+P)
        - Parametric cut shifts
        - Section enable/disable toggles
        - About dialog in menu
        """
    }
}

#Preview {
    AboutView()
}
