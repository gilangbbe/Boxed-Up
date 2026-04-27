//
//  HomeView.swift
//  Boxed Up
//
//  Created on 13/04/26.
//

import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: SparringViewModel
    var onCollectData: () -> Void
    var onTestGlove: () -> Void

    @State private var heroPulse = false

    private var canStartRound: Bool {
        switch viewModel.gameMode {
        case .singleHand: return viewModel.sessionManager.isWatchReachable
        case .glove:      return viewModel.gloveManager.isGloveConnected
        case .combo:      return viewModel.sessionManager.isWatchReachable && viewModel.gloveManager.isGloveConnected
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
            RadialGradient(
                colors: [Color.red.opacity(0.15), .clear],
                center: UnitPoint(x: 0.5, y: -0.1),
                startRadius: 0, endRadius: 460
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    fitnessSection.padding(.top, 28)
                    connectionBadges.padding(.top, 24)
                    modePicker.padding(.top, 32)
                    difficultyPicker.padding(.top, 24)
                    startButton.padding(.top, 32)
                    utilityRow.padding(.top, 16).padding(.bottom, 48)
                }
                .padding(.horizontal, 22)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: – Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(heroPulse ? 0.20 : 0.07))
                    .frame(width: 160, height: 160)
                    .blur(radius: 22)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: heroPulse)
                Image(systemName: "figure.boxing")
                    .font(.system(size: 78, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.22, blue: 0.18),
                                     Color(red: 1.0, green: 0.50, blue: 0.10)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .padding(.top, 52)
            .onAppear { heroPulse = true }

            VStack(spacing: 4) {
                Text("BOXED UP")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(5)
                Text("MOTION BOXING TRAINER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(white: 0.38))
                    .tracking(3.5)
            }
        }
    }

    // MARK: – Connection Badges

    private var connectionBadges: some View {
        HStack(spacing: 10) {
            if viewModel.gameMode != .glove {
                ConnectionBadge(
                    icon: viewModel.sessionManager.isWatchReachable
                        ? "applewatch.radiowaves.left.and.right" : "applewatch.slash",
                    label: "WATCH",
                    connected: viewModel.sessionManager.isWatchReachable
                )
            }
            if viewModel.gameMode == .combo || viewModel.gameMode == .glove {
                ConnectionBadge(
                    icon: viewModel.gloveManager.isGloveConnected
                        ? "hand.raised.fill" : "hand.raised.slash.fill",
                    label: "GLOVE",
                    connected: viewModel.gloveManager.isGloveConnected
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: – Mode Picker

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "GAME MODE", icon: "gamecontroller.fill")
            VStack(spacing: 8) {
                ForEach(SparringViewModel.GameMode.allCases, id: \.self) { mode in
                    GameModeCard(mode: mode, isSelected: viewModel.gameMode == mode) {
                        withAnimation(.easeInOut(duration: 0.2)) { viewModel.gameMode = mode }
                        if mode == .combo || mode == .glove {
                            viewModel.startGloveScanning()
                        } else {
                            viewModel.stopGloveScanning()
                        }
                    }
                }
            }
        }
    }

    // MARK: – Difficulty Picker

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "DIFFICULTY", icon: "speedometer")
            HStack(spacing: 8) {
                ForEach(RoundManager.Config.Difficulty.allCases, id: \.self) { diff in
                    DifficultyChip(
                        label: diff.rawValue.uppercased(),
                        color: difficultyColor(diff),
                        isSelected: viewModel.roundManager.config.difficulty == diff
                    ) {
                        viewModel.roundManager.config.difficulty = diff
                    }
                }
            }
        }
    }

    private func difficultyColor(_ d: RoundManager.Config.Difficulty) -> Color {
        switch d {
        case .easy:   return .green
        case .normal: return .orange
        case .hard:   return .red
        }
    }

    // MARK: – Start Button

    private var startButton: some View {
        Button { viewModel.startRound() } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill").font(.system(size: 15, weight: .bold))
                Text("START ROUND").font(.system(size: 17, weight: .bold)).tracking(1.5)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                Group {
                    if canStartRound {
                        LinearGradient(
                            colors: [Color(red: 1, green: 0.18, blue: 0.13),
                                     Color(red: 0.82, green: 0.08, blue: 0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            colors: [Color(white: 0.18), Color(white: 0.14)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(canStartRound ? Color.red.opacity(0.45) : Color.clear, lineWidth: 1)
            )
            .shadow(color: canStartRound ? Color.red.opacity(0.40) : .clear, radius: 14, y: 6)
        }
        .disabled(!canStartRound)
        .animation(.easeInOut(duration: 0.25), value: canStartRound)
    }

    // MARK: – Fitness Dashboard

    private var fitnessSection: some View {
        let store = viewModel.fitnessStore
        return VStack(spacing: 12) {
            SectionLabel(title: "TODAY'S ACTIVITY", icon: "chart.bar.fill")

            // Three daily stat tiles
            HStack(spacing: 10) {
                fitnessStatTile(
                    icon: "hand.raised.fill",
                    value: "\(store.todayPunches)",
                    label: "PUNCHES",
                    color: Color(red: 1, green: 0.18, blue: 0.13)
                )
                fitnessStatTile(
                    icon: "flame.fill",
                    value: String(format: "%.0f", store.todayCalories),
                    unit: "kcal",
                    label: "CALORIES",
                    color: Color(red: 1, green: 0.55, blue: 0.12)
                )
                fitnessStatTile(
                    icon: "clock.fill",
                    value: formatDuration(store.todayDuration),
                    label: "ACTIVE TIME",
                    color: Color(red: 0.28, green: 0.60, blue: 1.0)
                )
            }

            // Weekly chart + streak side by side
            HStack(alignment: .top, spacing: 10) {
                weeklyChartCard
                streakCard
            }
        }
    }

    private func fitnessStatTile(icon: String, value: String, unit: String = "", label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .black).monospacedDigit())
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(white: 0.42))
                }
            }
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color(white: 0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.14), lineWidth: 1))
    }

    private var weeklyChartCard: some View {
        let days = viewModel.fitnessStore.last7Days
        let maxCal = days.map(\.calories).max() ?? 0
        let weekTotal = viewModel.fitnessStore.weeklyCalories

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("THIS WEEK")
                    .font(.system(size: 9, weight: .bold)).tracking(2)
                    .foregroundStyle(Color(white: 0.35))
                Spacer()
                Text(String(format: "%.0f kcal", weekTotal))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(white: 0.30))
            }

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(days) { day in
                    let height: CGFloat = maxCal > 0
                        ? max(4, 42 * CGFloat(day.calories / maxCal))
                        : 4
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                day.hadSession
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [Color(red: 1, green: 0.18, blue: 0.13),
                                                 Color(red: 0.82, green: 0.08, blue: 0.04)],
                                        startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(Color(white: 0.15))
                            )
                            .frame(height: height)
                        Text(dayInitial(day.date))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(
                                Calendar.current.isDateInToday(day.date)
                                    ? Color.red
                                    : Color(white: 0.28)
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 54)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.14), lineWidth: 1))
    }

    private var streakCard: some View {
        let streak = viewModel.fitnessStore.currentStreak
        let sessions = viewModel.fitnessStore.totalSessionCount

        return VStack(spacing: 4) {
            Text("STREAK")
                .font(.system(size: 9, weight: .bold)).tracking(2)
                .foregroundStyle(Color(white: 0.35))

            Spacer()

            HStack(alignment: .center, spacing: 3) {
                Text("\(streak)")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(streak > 0 ? Color(red: 1, green: 0.55, blue: 0.12) : Color(white: 0.30))
                if streak > 0 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.12))
                }
            }
            Text("DAYS")
                .font(.system(size: 8, weight: .bold)).tracking(1.5)
                .foregroundStyle(Color(white: 0.35))

            Spacer()

            VStack(spacing: 2) {
                Text("\(sessions)")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                Text("SESSIONS")
                    .font(.system(size: 8, weight: .bold)).tracking(1)
                    .foregroundStyle(Color(white: 0.30))
            }
        }
        .padding(12)
        .frame(maxWidth: 100)
        .frame(maxHeight: .infinity)
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.14), lineWidth: 1))
    }

    // MARK: – Fitness Helpers

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        return String(format: "%d:%02d", m, s)
    }

    private func dayInitial(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return String(fmt.string(from: date).prefix(1))
    }

    // MARK: – Utility Row

    private var utilityRow: some View {
        HStack(spacing: 10) {
            UtilityButton(icon: "waveform.badge.plus", title: "Training Data", accentColor: .blue) {
                onCollectData()
            }
            UtilityButton(icon: "hand.raised.fingers.spread", title: "Test Glove",
                          accentColor: Color(red: 1, green: 0.55, blue: 0.1)) {
                onTestGlove()
            }
        }
    }
}

// MARK: - Sub-components

private struct SectionLabel: View {
    let title: String
    let icon: String
    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(white: 0.38))
            .tracking(2.5)
    }
}

private struct ConnectionBadge: View {
    let icon: String
    let label: String
    let connected: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(connected ? Color.green : Color(red: 1, green: 0.3, blue: 0.3))
                .frame(width: 6, height: 6)
            Image(systemName: icon).font(.system(size: 11))
            Text(label).font(.system(size: 10, weight: .bold)).tracking(1.2)
        }
        .foregroundStyle(connected ? Color.green : Color(red: 1, green: 0.4, blue: 0.4))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background((connected ? Color.green : Color.red).opacity(0.10))
        .clipShape(Capsule())
        .overlay(Capsule().stroke((connected ? Color.green : Color.red).opacity(0.28), lineWidth: 1))
    }
}

private struct GameModeCard: View {
    let mode: SparringViewModel.GameMode
    let isSelected: Bool
    let action: () -> Void

    private var info: (icon: String, subtitle: String) {
        switch mode {
        case .singleHand: return ("applewatch",          "Left Watch  •  Reaction training")
        case .glove:      return ("hand.raised.fill",    "Right Glove  •  Isolated glove mode")
        case .combo:      return ("hands.sparkles.fill", "Both Hands  •  Combo sequences")
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.red : Color(white: 0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: info.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? .white : Color(white: 0.45))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(info.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.42))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.red : Color(white: 0.22))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: isSelected ? 0.12 : 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.red.opacity(0.40) : Color(white: 0.13), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DifficultyChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold)).tracking(0.8)
                .foregroundStyle(isSelected ? .white : Color(white: 0.42))
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(isSelected ? color.opacity(0.9) : Color(white: 0.09))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? color : Color(white: 0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct UtilityButton: View {
    let icon: String
    let title: String
    let accentColor: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(accentColor)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(accentColor.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
