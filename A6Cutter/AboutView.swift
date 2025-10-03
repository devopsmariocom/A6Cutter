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
            let cleanVersion = version.hasPrefix("v") ? String(version.dropFirst()) : version
            print("DEBUG AboutView: CFBundleShortVersionString = '\(version)' -> cleanVersion = '\(cleanVersion)'")
            return cleanVersion
        }
        print("DEBUG AboutView: CFBundleShortVersionString not found")
        return "Deve"
    }
    
    private var buildNumber: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            // Check if this is a local build by looking at CFBundleShortVersionString
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                print("DEBUG AboutView: CFBundleVersion = '\(build)', version contains -dev: \(version.contains("-dev"))")
                if version.contains("-dev") {
                    // Local build - CFBundleVersion is git commit hash
                    print("DEBUG AboutView: Local build detected, returning git hash: '\(build)'")
                    return build
                } else {
                    // GitHub Actions build - CFBundleVersion is build number
                    print("DEBUG AboutView: GitHub Actions build detected, returning build number: '\(build)'")
                    return build
                }
            }
        }
        print("DEBUG AboutView: CFBundleVersion not found")
        return "dev"
    }
    
    private var gitHash: String {
        if let hash = Bundle.main.infoDictionary?["GitHash"] as? String {
            // Show first 7 characters of git hash for readability
            let shortHash = String(hash.prefix(7))
            print("DEBUG AboutView: GitHash = '\(hash)' -> shortHash = '\(shortHash)'")
            return shortHash
        }
        print("DEBUG AboutView: GitHash not found")
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
