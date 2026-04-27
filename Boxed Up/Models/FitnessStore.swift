//
//  FitnessStore.swift
//  Boxed Up
//

import Foundation

/// Persists session history and provides aggregated fitness stats: daily, weekly, streak, all-time.
@Observable
final class FitnessStore {

    // MARK: - User Profile

    /// Body weight used for calorie estimation. Defaults to 70 kg.
    var userWeightKg: Double = 70.0 {
        didSet { saveWeight() }
    }

    // MARK: - Session History

    private(set) var sessions: [SessionRecord] = []

    // MARK: - Persistence Keys

    private let sessionsKey = "boxedup.sessions.v1"
    private let weightKey   = "boxedup.userWeightKg"

    // MARK: - Init

    init() {
        let stored = UserDefaults.standard.double(forKey: weightKey)
        userWeightKg = stored > 30 ? stored : 70.0
        loadSessions()
    }

    // MARK: - Session Recording

    func addSession(_ record: SessionRecord) {
        sessions.append(record)
        saveSessions()
    }

    // MARK: - Calorie Estimation

    /// MET-based estimate. Boxing/sparring MET ≈ 7.8 (moderate intensity, ACSM reference).
    func estimateCalories(duration: TimeInterval) -> Double {
        let met = 7.8
        return met * userWeightKg * (duration / 3600.0)
    }

    // MARK: - Today

    var todaySessions: [SessionRecord] {
        sessions.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todayPunches: Int          { todaySessions.reduce(0) { $0 + $1.punchCount } }
    var todayCalories: Double      { todaySessions.reduce(0) { $0 + $1.calories } }
    var todayDuration: TimeInterval { todaySessions.reduce(0) { $0 + $1.duration } }
    var todaySessionCount: Int     { todaySessions.count }

    // MARK: - Weekly (last 7 calendar days)

    struct DayStat: Identifiable {
        let id = UUID()
        let date: Date
        let calories: Double
        let punches: Int
        let hadSession: Bool
    }

    var last7Days: [DayStat] {
        let cal = Calendar.current
        return (0..<7).reversed().map { daysAgo -> DayStat in
            let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let day = sessions.filter { cal.isDate($0.date, inSameDayAs: date) }
            return DayStat(
                date: date,
                calories: day.reduce(0) { $0 + $1.calories },
                punches:  day.reduce(0) { $0 + $1.punchCount },
                hadSession: !day.isEmpty
            )
        }
    }

    var weeklyCalories: Double { last7Days.reduce(0) { $0 + $1.calories } }

    // MARK: - Streak

    /// Consecutive days going backwards from today with at least one session.
    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = Date()
        // If no session today, start counting from yesterday
        if !sessions.contains(where: { cal.isDateInToday($0.date) }) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        while true {
            guard sessions.contains(where: { cal.isDate($0.date, inSameDayAs: checkDate) }) else { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    // MARK: - All-Time

    var totalSessionCount: Int   { sessions.count }
    var allTimePunches: Int      { sessions.reduce(0) { $0 + $1.punchCount } }
    var allTimeCalories: Double  { sessions.reduce(0) { $0 + $1.calories } }

    var bestSession: SessionRecord? {
        sessions.max(by: { $0.points < $1.points })
    }

    // MARK: - Persistence

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data)
        else { return }
        sessions = decoded
    }

    private func saveSessions() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: sessionsKey)
    }

    private func saveWeight() {
        UserDefaults.standard.set(userWeightKg, forKey: weightKey)
    }
}
