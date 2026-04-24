//
//  SparringView.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import SwiftUI
import UIKit

struct SparringView: View {
    @Bindable var viewModel: SparringViewModel

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

            VStack(spacing: 0) {
                scoreHUD
                    .padding(.top, 10)
                    .padding(.horizontal, 18)

                Spacer()

                centralRing

                Spacer()

                feedbackZone
                    .padding(.horizontal, 20)

                roundFooter
                    .padding(.top, 12)
                    .padding(.bottom, 34)
            }

            if viewModel.isDisconnected { disconnectOverlay }

            if viewModel.isShowingComboPreview {
                ComboPreviewOverlay(
                    combo: viewModel.comboManager.currentCombo,
                    comboNumber: viewModel.comboNumber,
                    totalCombos: viewModel.totalCombos
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.isShowingComboPreview)
        .preferredColorScheme(.dark)
        .onAppear  { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: – Score HUD

    private var scoreHUD: some View {
        HStack(spacing: 0) {
            ScoreCell(value: "\(Int(viewModel.score.totalPoints))",
                      label: "PTS", icon: "bolt.fill", color: .yellow)
            Rectangle().fill(Color(white: 0.14)).frame(width: 1, height: 34)
            ScoreCell(value: "×\(viewModel.score.currentStreak)",
                      label: "STREAK", icon: "flame.fill",
                      color: viewModel.score.currentStreak >= 3 ? .orange : Color(white: 0.35))
            Rectangle().fill(Color(white: 0.14)).frame(width: 1, height: 34)
            ScoreCell(value: String(format: "%.0f%%", safeAccuracy * 100),
                      label: "ACC", icon: "target",
                      color: accuracyColor(safeAccuracy))
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.14), lineWidth: 1))
    }

    // MARK: – Central Ring

    private var centralRing: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 10)

            Circle()
                .stroke(Color(white: 0.12), lineWidth: 5)
                .frame(width: 272, height: 272)

            if viewModel.isWaitingForPunch {
                Circle()
                    .trim(from: 0, to: viewModel.reactionTimeRemaining)
                    .stroke(
                        AngularGradient(
                            colors: [timerColor(for: viewModel.reactionTimeRemaining),
                                     timerColor(for: viewModel.reactionTimeRemaining).opacity(0.3)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * viewModel.reactionTimeRemaining)
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 272, height: 272)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: viewModel.reactionTimeRemaining)
            }

            actionContent
        }
    }

    @ViewBuilder
    private var actionContent: some View {
        if viewModel.gameMode == .combo { comboContent } else { singleHandContent }
    }

    private var singleHandContent: some View {
        Group {
            if let punch = viewModel.roundManager.currentAction {
                VStack(spacing: 8) {
                    Image(systemName: "figure.boxing")
                        .font(.system(size: 42))
                        .foregroundStyle(Color(white: 0.28))
                    Text(punch.rawValue.uppercased())
                        .font(.system(size: 46, weight: .black))
                        .foregroundStyle(.white)
                        .tracking(2)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.82).combined(with: .opacity),
                    removal:   .scale(scale: 1.08).combined(with: .opacity)
                ))
                .animation(.spring(duration: 0.35, bounce: 0.18), value: viewModel.roundManager.currentActionIndex)
            }
        }
    }

    private var comboContent: some View {
        VStack(spacing: 10) {
            if let step = viewModel.comboManager.currentStep {
                Text(step.hand == .left ? "LEFT" : "RIGHT")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(2)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(step.hand == .left ? Color.blue.opacity(0.85) : Color.red.opacity(0.85))
                    .clipShape(Capsule())
                Text(step.punch.rawValue.uppercased())
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(2)
            }
        }
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .animation(.spring(duration: 0.3, bounce: 0.15), value: viewModel.comboManager.currentStepIndex)
    }

    // MARK: – Feedback Zone

    @ViewBuilder
    private var feedbackZone: some View {
        ZStack {
            Color.clear.frame(height: 72)
            if let result = viewModel.lastPunchResult, let correct = viewModel.lastPunchCorrect {
                PunchFeedbackCard(result: result, correct: correct)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if viewModel.lastPunchCorrect == false && viewModel.lastPunchResult == nil {
                TimeoutCard()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if viewModel.isWaitingForPunch {
                Text("THROW YOUR PUNCH")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.28))
                    .tracking(2.5)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.lastPunchResult != nil)
    }

    // MARK: – Round Footer

    private var roundFooter: some View {
        VStack(spacing: 10) {
            if viewModel.gameMode == .combo && !viewModel.comboManager.currentCombo.isEmpty {
                ComboProgressView(
                    combo: viewModel.comboManager.currentCombo,
                    currentStepIndex: viewModel.comboManager.currentStepIndex,
                    stepResults: viewModel.comboStepResults
                )
                .padding(.horizontal, 18)
            }
            Group {
                if viewModel.gameMode == .combo {
                    Text("COMBO \(viewModel.comboNumber) OF \(viewModel.totalCombos)")
                } else {
                    Text("ACTION \(viewModel.roundManager.currentActionIndex + 1) OF \(viewModel.roundManager.config.actionsPerRound)")
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color(white: 0.28))
            .tracking(2)
        }
    }

    // MARK: – Disconnect Overlay

    private var disconnectOverlay: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.red.opacity(0.14)).frame(width: 90, height: 90).blur(radius: 10)
                    Image(systemName: "applewatch.slash")
                        .font(.system(size: 44)).foregroundStyle(.red)
                }
                VStack(spacing: 8) {
                    Text("Watch Disconnected")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    Text("Game paused — move closer\nto reconnect automatically.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.48))
                        .multilineTextAlignment(.center)
                }
                ProgressView().tint(Color(white: 0.5)).padding(.top, 4)
                Button { viewModel.endRound() } label: {
                    Text("END ROUND")
                        .font(.system(size: 13, weight: .bold)).tracking(1.2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 30).padding(.vertical, 12)
                        .background(Color.red.opacity(0.35))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.5), lineWidth: 1))
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: – Helpers

    private var safeAccuracy: Double {
        let a = viewModel.score.totalCount > 0 ? viewModel.score.accuracy : 0
        return a.isNaN || a.isInfinite ? 0 : max(0, min(1, a))
    }

    private func timerColor(for remaining: Double) -> Color {
        if remaining > 0.5 { return .green }
        if remaining > 0.25 { return .yellow }
        return .red
    }

    private func accuracyColor(_ a: Double) -> Color {
        if a >= 0.8 { return .green }
        if a >= 0.5 { return .orange }
        return .red
    }
}

// MARK: - Score Cell

private struct ScoreCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color)
                Text(value)
                    .font(.system(size: 21, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color(white: 0.32))
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Feedback Cards

private struct PunchFeedbackCard: View {
    let result: PunchResult
    let correct: Bool
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(correct ? .green : .red)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(result.punchType.rawValue.uppercased())  —  \(correct ? "CORRECT" : "WRONG")")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(correct ? Color.green : Color.red)
                Text(String(format: "%.2fs reaction  •  %.0f%% confidence",
                            result.reactionTime, result.confidence * 100))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.42))
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill((correct ? Color.green : Color.red).opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke((correct ? Color.green : Color.red).opacity(0.22), lineWidth: 1)
                )
        )
    }
}

private struct TimeoutCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 30)).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("TOO SLOW!")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.orange)
                Text("Reaction window expired")
                    .font(.system(size: 11)).foregroundStyle(Color(white: 0.42))
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.22), lineWidth: 1)
                )
        )
    }
}

// MARK: - Combo Progress View

private struct ComboProgressView: View {
    let combo: [ComboAction]
    let currentStepIndex: Int
    let stepResults: [Bool?]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(combo.enumerated()), id: \.offset) { index, action in
                stepView(for: action, at: index)
                if index < combo.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(white: 0.22))
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func stepView(for action: ComboAction, at index: Int) -> some View {
        let result  = index < stepResults.count ? stepResults[index] : nil
        let isCurrent = index == currentStepIndex

        VStack(spacing: 5) {
            Text(action.hand == .left ? "L" : "R")
                .font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(action.hand == .left ? Color.blue : Color.red)
                .clipShape(Circle())
            Text(action.punch.rawValue.prefix(3).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isCurrent ? .white : Color(white: 0.38))
            if let r = result {
                Image(systemName: r ? "checkmark" : "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(r ? Color.green : Color.red)
            } else {
                Circle().fill(isCurrent ? Color.orange : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: 52)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(stepBg(result: result, isCurrent: isCurrent))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(stepBorder(result: result, isCurrent: isCurrent), lineWidth: 1)
                )
        )
    }

    private func stepBg(result: Bool?, isCurrent: Bool) -> Color {
        if let r = result { return (r ? Color.green : Color.red).opacity(0.12) }
        if isCurrent { return Color.orange.opacity(0.12) }
        return Color(white: 0.08)
    }

    private func stepBorder(result: Bool?, isCurrent: Bool) -> Color {
        if let r = result { return (r ? Color.green : Color.red).opacity(0.30) }
        if isCurrent { return Color.orange.opacity(0.40) }
        return Color(white: 0.14)
    }
}

// MARK: - Combo Preview Overlay

private struct ComboPreviewOverlay: View {
    let combo: [ComboAction]
    let comboNumber: Int
    let totalCombos: Int

    private let previewDuration: Double = 3.0
    @State private var fillProgress: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.03, blue: 0.05)
                .opacity(0.97)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 6) {
                    Text("INCOMING COMBO")
                        .font(.system(size: 11, weight: .bold)).tracking(3.5)
                        .foregroundStyle(Color(white: 0.35))
                    Text("COMBO \(comboNumber) OF \(totalCombos)")
                        .font(.system(size: 22, weight: .black)).tracking(2)
                        .foregroundStyle(.white)
                }

                // Step cards
                HStack(spacing: 0) {
                    ForEach(Array(combo.enumerated()), id: \.offset) { i, action in
                        let isLeft = action.hand == .left
                        let handColor: Color = isLeft ? .blue : .red

                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(handColor.opacity(0.18))
                                    .frame(width: 52, height: 52)
                                Text(isLeft ? "L" : "R")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(handColor)
                            }
                            Text(action.punch.rawValue.uppercased())
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)
                                .tracking(1.5)
                            Text(isLeft ? "WATCH" : "GLOVE")
                                .font(.system(size: 9, weight: .bold)).tracking(2)
                                .foregroundStyle(Color(white: 0.35))
                        }
                        .frame(maxWidth: .infinity).frame(height: 120)
                        .background(Color(white: 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(handColor.opacity(0.25), lineWidth: 1)
                        )

                        if i < combo.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(white: 0.22))
                                .frame(width: 28)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Countdown bar
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(white: 0.12))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1, green: 0.18, blue: 0.13),
                                                 Color(red: 0.82, green: 0.08, blue: 0.04)],
                                        startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * fillProgress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 24)

                    Text("GET READY")
                        .font(.system(size: 11, weight: .bold)).tracking(3)
                        .foregroundStyle(Color(white: 0.32))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: previewDuration)) {
                fillProgress = 1.0
            }
        }
    }
}
