//
//  ShareView.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 1/10/26.
//

import SwiftUI

enum ShareStatus {
    case extracting
    case success(String)
    case error
}

struct ShareView: View {
    let status: ShareStatus
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                switch status {
                case .extracting:
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Extracting Recipe...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                case .success(let recipeName):
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.green)
                    Text("Saved!")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(recipeName)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                case .error:
                    Image(systemName: "exclamationmark.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.red)
                    Text("No Recipe Found")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Could not detect a recipe on this page.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(30)
            .background(.thinMaterial)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: status == .extracting) // Simple animation hack
    }
}

// Enable simple enum equality for animation
extension ShareStatus: Equatable {
    static func == (lhs: ShareStatus, rhs: ShareStatus) -> Bool {
        switch (lhs, rhs) {
        case (.extracting, .extracting): return true
        case (.error, .error): return true
        case (.success(let a), .success(let b)): return a == b
        default: return false
        }
    }
}
