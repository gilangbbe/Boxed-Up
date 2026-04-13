//
//  WatchHomeView.swift
//  Boxed Up Watch Watch App
//
//  Created on 13/04/26.
//

import SwiftUI

struct WatchHomeView: View {
    var sessionManager: WatchSessionManager

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.boxing")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text("Boxed Up")
                .font(.headline)

            HStack(spacing: 4) {
                Image(systemName: sessionManager.isPhoneReachable ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                    .foregroundStyle(sessionManager.isPhoneReachable ? .green : .red)
                Text(sessionManager.isPhoneReachable ? "Ready" : "No iPhone")
                    .font(.caption2)
                    .foregroundStyle(sessionManager.isPhoneReachable ? .green : .red)
            }
        }
    }
}
