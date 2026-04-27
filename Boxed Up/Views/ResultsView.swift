//
//  ResultsView.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import SwiftUI

struct ResultsView: View {
    @Bindable var viewModel: SparringViewModel

    @State private var ringAppeared = false

    private var safeAccuracy: Double {
        let a = viewModel.score.totalCount > 0 ? viewModel.score.accuracy : 0
        return a.isNaN || a.isInfinite ? 0 : max(0, min(1, a))
    }

    private var grade: (letter: String, color: Color) {
        let a = safeAccuracy
        let t = viewModel.score.avgReactionTime
        if a >= 0.9 && t < 0.4 { return ("S", Color(red: 1.0, green: 0.85, blue: 0.10)) }
        if a >= 0.8             { return ("A", .green) }
        if a >= 0.65            { return ("B", Color(red: 0.2, green: 0.72, blue: 1.0)) }
        if a >= 0.5             { return ("C", .orange) }
        return ("D", .red)
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
            RadialGradient(
                colors: [grade.color.opacity(0.14), .clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 0, endRadius: 450
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 5) {
                        Text("ROUND COMPLETE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(white: 0.35))
                            .tracking(3.5)
                        Text("Final Results")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 52)

                    // Grade ring
                    ZStack {
                        Circle()
                            .stroke(Color(white: 0.10), lineWidth: 10)
                            .frame(width: 164, height: 164)
                        Circle()
                            .trim(from: 0, to: ringAppeared ? safeAccuracy : 0)
                            .stroke(
                                LinearGradient(
                                    colors: [grade.color, grade.color.opacity(0.35)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 164, height: 164)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.2), value: ringAppeared)
                        VStack(spacing: 1) {
                            Text(grade.letter)
                                .font(.system(size: 56, weight: .black))
                                .foregroundStyle(grade.color)
                            Text("\(Int(viewModel.score.totalPoints)) PTS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(white: 0.38))
                                .tracking(1.2)
                        }
                    }
                    .padding(.top, 24)
                    .onAppear { ringAppeared = true }

                    // Stats card
                    VStack(spacing: 0) {
                        ResultStatRow(icon: "target",
                                      label: "Accuracy",
                                      value: String(format: "%.0f%%", safeAccuracy * 100),
                                      color: .blue)
                        Divider().background(Color.white.opacity(0.06))
                        ResultStatRow(icon: "timer",
                                      label: "Avg Reaction",
                                      value: String(format: "%.2f s", viewModel.score.avgReactionTime),
                                      color: .orange)
                        Divider().background(Color.white.opacity(0.06))
                        ResultStatRow(icon: "flame.fill",
                                      label: "Best Streak",
                                      value: "×\(viewModel.score.bestStreak)",
                                      color: .red)
                        Divider().background(Color.white.opacity(0.06))
                        ResultStatRow(icon: "checkmark.circle.fill",
                                      label: "Correct",
                                      value: "\(viewModel.score.correctCount) / \(viewModel.score.totalCount)",
                                      color: .green)
                        Divider().background(Color.white.opacity(0.06))
                        ResultStatRow(icon: "clock.fill",
                                      label: "Duration",
                                      value: formatDuration(viewModel.lastRoundDuration),
                                      color: Color(red: 0.28, green: 0.60, blue: 1.0))
                        Divider().background(Color.white.opacity(0.06))
                        ResultStatRow(icon: "flame.fill",
                                      label: "Calories Burned",
                                      value: String(format: "%.0f kcal", viewModel.lastRoundCalories),
                                      color: Color(red: 1, green: 0.55, blue: 0.12))
                    }
                    .background(Color(white: 0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.13), lineWidth: 1))
                    .padding(.horizontal, 22)
                    .padding(.top, 28)

                    // Today's activity summary
                    todayActivityStrip
                        .padding(.horizontal, 22)
                        .padding(.top, 14)

                    // Action buttons
                    VStack(spacing: 10) {
                        Button { viewModel.startRound() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.counterclockwise").font(.system(size: 15, weight: .bold))
                                Text("PLAY AGAIN").font(.system(size: 17, weight: .bold)).tracking(1.5)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 60)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 1, green: 0.18, blue: 0.13),
                                             Color(red: 0.82, green: 0.08, blue: 0.04)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 17))
                            .shadow(color: Color.red.opacity(0.38), radius: 14, y: 5)
                        }

                        Button { viewModel.returnToHome() } label: {
                            Text("HOME")
                                .font(.system(size: 16, weight: .semibold)).tracking(1.2)
                                .foregroundStyle(Color(white: 0.45))
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(Color(white: 0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(white: 0.14), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 28)
                    .padding(.bottom, 44)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: – Today Activity Strip

    private var todayActivityStrip: some View {
        let store = viewModel.fitnessStore
        return HStack(spacing: 0) {
            todayActivityCell(
                icon: "hand.raised.fill",
                value: "\(store.todayPunches)",
                label: "PUNCHES TODAY",
                color: Color(red: 1, green: 0.18, blue: 0.13)
            )
            Divider()
                .frame(height: 30)
                .background(Color(white: 0.14))
            todayActivityCell(
                icon: "flame.fill",
                value: String(format: "%.0f kcal", store.todayCalories),
                label: "TODAY",
                color: Color(red: 1, green: 0.55, blue: 0.12)
            )
            Divider()
                .frame(height: 30)
                .background(Color(white: 0.14))
            todayActivityCell(
                icon: "clock.fill",
                value: formatDuration(store.todayDuration),
                label: "ACTIVE",
                color: Color(red: 0.28, green: 0.60, blue: 1.0)
            )
        }
        .padding(.vertical, 12)
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.13), lineWidth: 1))
    }

    private func todayActivityCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8, weight: .bold)).tracking(1)
                .foregroundStyle(Color(white: 0.35))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Helpers

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        return String(format: "%d:%02d", m, s)
    }
}

private struct ResultStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16)).foregroundStyle(color).frame(width: 24)
            Text(label)
                .font(.system(size: 15)).foregroundStyle(Color(white: 0.52))
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .bold).monospacedDigit()).foregroundStyle(.white)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }
}
