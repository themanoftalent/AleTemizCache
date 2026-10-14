import SwiftUI
import TemizCacheCore

struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Page(title: "Overview", subtitle: subtitle) {
            hero
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) { tiles }
                VStack(spacing: 16) { tiles }
            }
            breakdown
            largest
        }
    }

    private var subtitle: String {
        if model.isScanning { return "Measuring cache folders…" }
        guard let lastScan = model.lastScan else { return "Not scanned yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last scanned \(formatter.localizedString(for: lastScan, relativeTo: Date()))"
    }

    // MARK: Hero

    private var hero: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reclaimable space")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                BytesText(bytes: model.isScanning && model.totalBytes == 0 ? nil : model.totalBytes, placeholder: "Measuring…")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(ByteText.string(model.selectedBytes)) selected across \(model.selectedNonEmptyCount) of \(model.rows.count) locations")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    model.requestCleanSelected()
                } label: {
                    Label("Clean Selected", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Theme.accentDeep)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(Color.white, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .opacity(model.selectedNonEmptyCount == 0 || model.isBusy ? 0.55 : 1)
                .disabled(model.selectedNonEmptyCount == 0 || model.isBusy)

                Button("Rescan") { Task { await model.refreshAll() } }
                    .buttonStyle(.plain)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .disabled(model.isBusy)
            }
        }
        .padding(24)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if model.isScanning {
                ProgressView(value: Double(model.scannedCount), total: Double(max(1, model.rows.count)))
                    .tint(.white)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Tiles

    @ViewBuilder
    private var tiles: some View {
        diskTile
        trashTile
        historyTile
    }

    private var diskTile: some View {
        HStack(spacing: 16) {
            RingGauge(fraction: model.disk?.usedFraction ?? 0,
                      color: (model.disk?.usedFraction ?? 0) > 0.9 ? Theme.trash : Theme.accent)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("Disk").font(.subheadline).foregroundStyle(.secondary)
                BytesText(bytes: model.disk?.available)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text("free of \(model.disk.map { ByteText.string($0.total) } ?? "—")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var trashTile: some View {
        Button {
            model.selection = .trash
        } label: {
            HStack(spacing: 16) {
                IconBadge(symbol: "trash.fill", color: Theme.trash, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trash").font(.subheadline).foregroundStyle(.secondary)
                    if let trash = model.trash, trash.readable {
                        BytesText(bytes: trash.bytes)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        Text("\(trash.itemCount) item(s)").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Access needed").font(.system(.title3, design: .rounded).weight(.bold))
                        Text("Open to measure or empty").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
        .accessibilityHint("Opens the Trash section")
    }

    private var historyTile: some View {
        HStack(spacing: 16) {
            IconBadge(symbol: "leaf.fill", color: .green, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("Freed so far").font(.subheadline).foregroundStyle(.secondary)
                BytesText(bytes: model.history.lifetimeBytes)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                if let last = model.history.lastRun {
                    Text("Last cleanup \(last.formatted(.relative(presentation: .named)))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("No cleanups yet").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    // MARK: Breakdown

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Breakdown", subtitle: "Space used by each kind of cache")
            let total = max(1, model.totalBytes)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(model.kindsInUse, id: \.self) { kind in
                        let width = geo.size.width * CGFloat(Double(model.bytes(for: kind)) / Double(total))
                        if width > 0.5 {
                            Rectangle()
                                .fill(Theme.color(for: kind).gradient)
                                .frame(width: width)
                        }
                    }
                    if model.totalBytes == 0 {
                        Rectangle().fill(Color.primary.opacity(0.08))
                    }
                }
                .clipShape(Capsule())
                .animation(.easeOut(duration: 0.5), value: model.totalBytes)
            }
            .frame(height: 14)
            .accessibilityHidden(true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
                ForEach(model.kindsInUse, id: \.self) { kind in
                    let bytes = model.bytes(for: kind)
                    Button {
                        model.selection = .category(kind)
                    } label: {
                        HStack(spacing: 10) {
                            Circle().fill(Theme.color(for: kind)).frame(width: 10, height: 10)
                            Text(kind.title)
                                .lineLimit(1)
                                .layoutPriority(1)
                            Spacer(minLength: 6)
                            BytesText(bytes: bytes).foregroundStyle(.secondary)
                            Text(percent(bytes, of: total))
                                .font(.caption).foregroundStyle(.tertiary)
                                .frame(width: 36, alignment: .trailing)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(kind.title), \(ByteText.string(bytes))")
                    .accessibilityHint("Shows these locations")
                }
            }
        }
        .card()
    }

    private func percent(_ part: Int64, of total: Int64) -> String {
        "\(Int((Double(part) / Double(max(1, total)) * 100).rounded()))%"
    }

    // MARK: Largest

    @ViewBuilder
    private var largest: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Largest locations")
            if model.largestRows.isEmpty {
                Text(model.isScanning ? "Measuring…" : "Every cache location is empty. Nothing to clean.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(model.largestRows) { row in
                    ItemCard(row: row, compact: true)
                }
            }
        }
    }
}
