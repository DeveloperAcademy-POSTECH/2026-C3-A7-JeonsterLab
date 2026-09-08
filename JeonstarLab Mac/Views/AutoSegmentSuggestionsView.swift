import SwiftUI

struct AutoSegmentSuggestionsView: View {
    @State private var isExpanded = true
    let review: AutoSegmentReview?
    let selectedID: String?
    let isAnalyzing: Bool
    let canAnalyze: Bool
    let message: String?
    let onAnalyze: () -> Void
    let onCancel: () -> Void
    let onSelect: (AutoSegmentCandidate) -> Void
    let onDismiss: (AutoSegmentCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Auto Segments").font(.headline)
                Spacer()
                if isAnalyzing {
                    ProgressView().controlSize(.small)
                    Button("Cancel", action: onCancel)
                } else {
                    Button(review == nil ? "Suggest Segments" : "Analyze Again", action: onAnalyze)
                        .disabled(!canAnalyze)
                }
            }
            Text("Dashed ranges are suggestions. Review and confirm them before adding them to a dataset.")
                .font(.caption).foregroundStyle(.secondary)
            if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
            if let review {
                if review.pending.isEmpty {
                    Text(review.candidates.isEmpty ? "No new activity ranges found. You can still select a range manually." : "All suggestions reviewed.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    DisclosureGroup("\(review.pending.count) \(review.pending.count == 1 ? "suggestion" : "suggestions")", isExpanded: $isExpanded) {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(Array(review.candidates.enumerated()), id: \.element.id) { index, candidate in
                                    if candidate.status == .pending {
                                        HStack(spacing: 8) {
                                            Button { onSelect(candidate) } label: {
                                                HStack {
                                                    Text("Segment \(index + 1)")
                                                    Spacer(minLength: 8)
                                                    Text(String(format: "%.2f–%.2f s", candidate.startTime, candidate.endTime))
                                                        .monospacedDigit()
                                                }
                                                .padding(8).frame(maxWidth: .infinity)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .background(selectedID == candidate.id ? EditorPalette.accent.opacity(0.15) : Color.clear,
                                                        in: RoundedRectangle(cornerRadius: 6))
                                            Button { onDismiss(candidate) } label: {
                                                Label("Dismiss Segment \(index + 1)", systemImage: "xmark")
                                            }
                                            .labelStyle(.iconOnly).buttonStyle(.borderless)
                                            .help("Dismiss this suggestion; keep the original recording")
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 160)
                    }
                }
                if review.reachedLimit {
                    Text("Analysis stopped at 2,000 suggestions. Split long recordings for further review.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .padding(14).editorSurface()
    }
}
