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
            ScrollView {
                VStack(spacing: 24) {
                    labelPicker
                    sourcePicker
                    sessionCountsGrid
                    recordingArea
                    statusBar
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Collect Training Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        onDone()
                    }
                    .disabled(viewModel.isRecording || viewModel.countdown != nil)
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all \(viewModel.totalSessions) recorded sessions.")
            }
        }
    }

    // MARK: - Label Picker

    private var labelPicker: some View {
        VStack(spacing: 12) {
            Text("Select Punch Type")
                .font(.headline)

            Picker("Label", selection: $viewModel.selectedLabel) {
                ForEach(DataCollectionLabel.allCases, id: \.self) { label in
                    Text(label.displayName).tag(label)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isRecording || viewModel.countdown != nil)

            Text(viewModel.selectedLabel.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Session Counts

    private var sessionCountsGrid: some View {
        VStack(spacing: 8) {
            Text("Sessions Collected")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(DataCollectionLabel.allCases, id: \.self) { label in
                    VStack(spacing: 4) {
                        Image(systemName: label.iconName)
                            .font(.title2)
                            .foregroundStyle(label == viewModel.selectedLabel ? .blue : .secondary)
                        Text(label.displayName)
                            .font(.caption2)
                        Text(viewModel.sessionCountText(for: label))
                            .font(.title3.bold())
                            .foregroundStyle(countColor(for: viewModel.progressCount(for: label)))
                    }
                    .padding(8)
                    .background(label == viewModel.selectedLabel ? Color.blue.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Text("Recommended: 50+ sessions per type")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Source Picker

    private var sourcePicker: some View {
        VStack(spacing: 12) {
            Text("Collection Source")
                .font(.headline)

            Picker("Source", selection: $viewModel.selectedSource) {
                ForEach(DataCollectionSource.allCases, id: \.self) { source in
                    Text(source.displayName).tag(source)
                }
            }
            .pickerStyle(.menu)
            .disabled(viewModel.isRecording || viewModel.countdown != nil)

            Text("Smart Glove is fixed on RIGHT hand. Watch data is stored as LEFT hand.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Recording Area

    private var recordingArea: some View {
        VStack(spacing: 16) {
            if let countdown = viewModel.countdown {
                Text("\(countdown)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: countdown)

                Text("Get Ready...")
                    .font(.title3)
                    .foregroundStyle(.secondary)

            } else if viewModel.isRecording {
                VStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(.red.opacity(0.5), lineWidth: 4))

                    Text("Recording...")
                        .font(.title2.bold())
                        .foregroundStyle(.red)

                    Text("\(viewModel.recordingSampleCount) samples")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Throw a \(viewModel.selectedLabel.displayName)!")
                        .font(.headline)
                }
                .frame(height: 160)

            } else {
                Button {
                    viewModel.startRecording()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 60))
                        Text("Record \(viewModel.selectedLabel.displayName)")
                            .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!viewModel.canRecord)
            }
        }
    }

    // MARK: - Status

    private var statusBar: some View {
        VStack(spacing: 8) {
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Image(systemName: viewModel.sessionManager.isWatchReachable
                      ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                    .foregroundStyle(viewModel.sessionManager.isWatchReachable ? .green : .red)
                Text(viewModel.sessionManager.isWatchReachable ? "Left Watch Connected" : "Left Watch Not Connected")
                    .font(.caption)
                    .foregroundStyle(viewModel.sessionManager.isWatchReachable ? .green : .red)
            }

            HStack {
                Image(systemName: viewModel.gloveManager.isGloveConnected
                      ? "hand.raised.fingers.spread.fill" : "hand.raised.slash.fill")
                    .foregroundStyle(viewModel.gloveManager.isGloveConnected ? .green : .red)
                Text(viewModel.gloveManager.isGloveConnected ? "Right Smart Glove Connected" : "Right Smart Glove Not Connected")
                    .font(.caption)
                    .foregroundStyle(viewModel.gloveManager.isGloveConnected ? .green : .red)
            }

            if !viewModel.gloveManager.isGloveConnected {
                Button {
                    if viewModel.gloveManager.isScanning {
                        viewModel.gloveManager.stopScanning()
                    } else {
                        viewModel.gloveManager.startScanning()
                    }
                } label: {
                    Label(viewModel.gloveManager.isScanning ? "Scanning Smart Glove..." : "Connect Smart Glove", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                exportURL = viewModel.exportTrainingData()
                if exportURL != nil {
                    showExportSheet = true
                }
            } label: {
                Label("Export Training Data", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.totalSessions == 0)

            Button {
                showDeleteConfirm = true
            } label: {
                Label("Delete All Data", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.totalSessions == 0)
        }
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
