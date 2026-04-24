//
//  DataCollectionView.swift
//  Boxed Up
//
//  Created on 14/04/26.
//

import SwiftUI

/// iPhone UI for recording labeled training data sessions from Watch and Smart Glove motion.
struct DataCollectionView: View {
    @Bindable var viewModel: DataCollectionViewModel
    var onDone: () -> Void

    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        labelPicker
                        sourcePicker
                        sessionCountsGrid
                        recordingArea
                        statusBar
                        actionButtons
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Training Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.05, green: 0.05, blue: 0.07), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { onDone() }
                        .foregroundStyle(.red)
                        .disabled(viewModel.isRecording || viewModel.countdown != nil)
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL { ShareSheet(activityItems: [url]) }
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { viewModel.deleteAllData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all \(viewModel.totalSessions) recorded sessions.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Label Picker

    private var labelPicker: some View {
        VStack(spacing: 10) {
            Text("PUNCH TYPE")
                .font(.system(size: 10, weight: .bold)).tracking(2.5)
                .foregroundStyle(Color(white: 0.38))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(DataCollectionLabel.allCases, id: \.self) { label in
                    Button { viewModel.selectedLabel = label } label: {
                        VStack(spacing: 4) {
                            Image(systemName: label.iconName).font(.system(size: 18))
                            Text(label.displayName).font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(viewModel.selectedLabel == label ? .white : Color(white: 0.42))
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(viewModel.selectedLabel == label ? Color.red.opacity(0.85) : Color(white: 0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.selectedLabel == label ? Color.red : Color(white: 0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isRecording || viewModel.countdown != nil)
                }
            }

            Text(viewModel.selectedLabel.description)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.42))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Session Counts

    private var sessionCountsGrid: some View {
        VStack(spacing: 10) {
            HStack {
                Text("SESSIONS COLLECTED")
                    .font(.system(size: 10, weight: .bold)).tracking(2)
                    .foregroundStyle(Color(white: 0.38))
                Spacer()
                Text("\(viewModel.totalSessions) total")
                    .font(.system(size: 11)).foregroundStyle(Color(white: 0.38))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(DataCollectionLabel.allCases, id: \.self) { label in
                    let isSelected = label == viewModel.selectedLabel
                    let count = viewModel.progressCount(for: label)
                    VStack(spacing: 4) {
                        Image(systemName: label.iconName)
                            .font(.system(size: 18))
                            .foregroundStyle(isSelected ? .white : Color(white: 0.45))
                        Text("\(count)")
                            .font(.system(size: 20, weight: .bold).monospacedDigit())
                            .foregroundStyle(countColor(for: count))
                        Text(label.displayName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(white: 0.38))
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? Color.red.opacity(0.12) : Color(white: 0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.red.opacity(0.35) : Color(white: 0.13), lineWidth: 1)
                    )
                }
            }

            Text("Target: 50+ sessions per type")
                .font(.system(size: 10)).foregroundStyle(Color(white: 0.32))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Source Picker

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COLLECTION SOURCE")
                .font(.system(size: 10, weight: .bold)).tracking(2.5)
                .foregroundStyle(Color(white: 0.38))

            Picker("Source", selection: $viewModel.selectedSource) {
                ForEach(DataCollectionSource.allCases, id: \.self) { source in
                    Text(source.displayName).tag(source)
                }
            }
            .pickerStyle(.menu)
            .tint(.red)
            .disabled(viewModel.isRecording || viewModel.countdown != nil)

            Text("Smart Glove = RIGHT hand  •  Watch data = LEFT hand")
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.38))
        }
    }

    // MARK: - Recording Area

    private var recordingArea: some View {
        VStack(spacing: 16) {
            if let countdown = viewModel.countdown {
                VStack(spacing: 8) {
                    Text("\(countdown)")
                        .font(.system(size: 88, weight: .black))
                        .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.1))
                        .contentTransition(.numericText())
                        .animation(.easeInOut, value: countdown)
                    Text("GET READY")
                        .font(.system(size: 13, weight: .bold)).tracking(2)
                        .foregroundStyle(Color(white: 0.45))
                }
                .frame(maxWidth: .infinity).frame(height: 160)
                .background(Color(white: 0.09))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            } else if viewModel.isRecording {
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.red.opacity(0.15)).frame(width: 64, height: 64)
                        Circle().fill(Color.red).frame(width: 18, height: 18)
                    }
                    Text("RECORDING")
                        .font(.system(size: 16, weight: .bold)).tracking(1.5)
                        .foregroundStyle(.red)
                    Text("\(viewModel.recordingSampleCount) samples")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(white: 0.50))
                    Text("Throw a \(viewModel.selectedLabel.displayName)!")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity).frame(height: 160)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.red.opacity(0.22), lineWidth: 1))

            } else {
                Button { viewModel.startRecording() } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "record.circle").font(.system(size: 52))
                        Text("RECORD  \(viewModel.selectedLabel.displayName.uppercased())")
                            .font(.system(size: 14, weight: .bold)).tracking(1)
                    }
                    .foregroundStyle(viewModel.canRecord ? .red : Color(white: 0.35))
                    .frame(maxWidth: .infinity).frame(height: 160)
                    .background(viewModel.canRecord ? Color.red.opacity(0.09) : Color(white: 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(viewModel.canRecord ? Color.red.opacity(0.22) : Color(white: 0.12), lineWidth: 1)
                    )
                }
                .disabled(!viewModel.canRecord)
            }
        }
    }

    // MARK: - Status

    private var statusBar: some View {
        VStack(spacing: 8) {
            Text(viewModel.statusMessage)
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.50))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                connectionPill(
                    icon: viewModel.sessionManager.isWatchReachable
                        ? "applewatch.radiowaves.left.and.right" : "applewatch.slash",
                    label: "Left Watch",
                    connected: viewModel.sessionManager.isWatchReachable
                )
                connectionPill(
                    icon: viewModel.gloveManager.isGloveConnected
                        ? "hand.raised.fingers.spread.fill" : "hand.raised.slash.fill",
                    label: "Right Glove",
                    connected: viewModel.gloveManager.isGloveConnected
                )
            }

            if !viewModel.gloveManager.isGloveConnected {
                Button {
                    if viewModel.gloveManager.isScanning { viewModel.gloveManager.stopScanning() }
                    else { viewModel.gloveManager.startScanning() }
                } label: {
                    Label(
                        viewModel.gloveManager.isScanning ? "Scanning..." : "Connect Smart Glove",
                        systemImage: "dot.radiowaves.left.and.right"
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.1))
                }
            }
        }
    }

    private func connectionPill(icon: String, label: String, connected: Bool) -> some View {
        HStack(spacing: 5) {
            Circle().fill(connected ? Color.green : Color.red).frame(width: 6, height: 6)
            Image(systemName: icon).font(.system(size: 11))
            Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.5)
        }
        .foregroundStyle(connected ? Color.green : Color.red.opacity(0.8))
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background((connected ? Color.green : Color.red).opacity(0.10))
        .clipShape(Capsule())
        .overlay(Capsule().stroke((connected ? Color.green : Color.red).opacity(0.25), lineWidth: 1))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                exportURL = viewModel.exportTrainingData()
                if exportURL != nil { showExportSheet = true }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .semibold))
                    Text("EXPORT TRAINING DATA").font(.system(size: 14, weight: .bold)).tracking(0.8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(
                    viewModel.totalSessions > 0
                        ? LinearGradient(
                            colors: [Color(red: 0.18, green: 0.48, blue: 1.0),
                                     Color(red: 0.10, green: 0.35, blue: 0.85)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(
                            colors: [Color(white: 0.16), Color(white: 0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .disabled(viewModel.totalSessions == 0)

            Button { showDeleteConfirm = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash").font(.system(size: 13))
                    Text("Delete All Data").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(viewModel.totalSessions > 0 ? Color.red : Color(white: 0.35))
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(viewModel.totalSessions > 0 ? Color.red.opacity(0.10) : Color(white: 0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.totalSessions > 0 ? Color.red.opacity(0.22) : Color(white: 0.12), lineWidth: 1)
                )
            }
            .disabled(viewModel.totalSessions == 0)
        }
        .padding(.bottom, 8)
    }

    private func countColor(for count: Int) -> Color {
        if count >= 50 { return .green }
        if count >= 20 { return .orange }
        return .red
    }
}

// MARK: - Share Sheet (UIKit wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
