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
        VStack(spacing: 10) {
            Image(systemName: "figure.boxing")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.22, blue: 0.18),
                                 Color(red: 1.0, green: 0.50, blue: 0.10)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            Text("BOXED UP")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
                .tracking(2)

            HStack(spacing: 5) {
                Circle()
                    .fill(sessionManager.isPhoneReachable ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(sessionManager.isPhoneReachable ? "READY" : "NO iPHONE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(sessionManager.isPhoneReachable ? .green : .red)
                    .tracking(0.8)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background((sessionManager.isPhoneReachable ? Color.green : Color.red).opacity(0.15))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
