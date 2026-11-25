import AppKit
import SwiftUI
import VoiceBarCore

enum LisanStyle {
    static let orange = Color(red: 198 / 255, green: 93 / 255, blue: 50 / 255)
    static let border = Color.primary.opacity(0.06)
}

struct LisanWindowView: View {
    @ObservedObject var state: AppState
    let controller: DictationController

    var body: some View {
        HStack(spacing: 0) {
            LisanSidebar(selection: $state.selectedTab)
            Divider()
            Group {
                if state.selectedTab == .notes {
                    NotesView(store: state.notes, shortcut: state.shortcut)
                } else {
                    SettingsView(state: state, controller: controller)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 760, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(LisanStyle.orange)
    }
}

struct LisanSidebar: View {
    @Binding var selection: AppTab

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(spacing: 9) {
                Image(nsImage: BrandIcon.artwork)
                    .resizable().interpolation(.high).scaledToFit().frame(width: 42, height: 42)
                    .accessibilityHidden(true)
                Text("lisan").font(.system(size: 23, weight: .semibold, design: .rounded)).tracking(-0.7)
            }
            .padding(.horizontal, 6).padding(.top, 12)

            VStack(spacing: 6) {
                ForEach(AppTab.allCases) { tab in
                    Button { selection = tab } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon).font(.system(size: 15)).frame(width: 20)
                            Text(tab.rawValue).font(.system(size: 13, weight: selection == tab ? .semibold : .medium))
                            Spacer()
                        }
                        .foregroundStyle(selection == tab ? LisanStyle.orange : .secondary)
                        .padding(.horizontal, 12).frame(height: 40)
                        .background(selection == tab ? LisanStyle.orange.opacity(0.10) : .clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 5) {
                Text("A thought, kept.").font(.system(size: 12, weight: .medium))
                Text("Made room for by your voice.").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary).padding(.horizontal, 10).padding(.bottom, 10)
        }
        .padding(16).frame(width: 180)
        .frame(maxHeight: .infinity)
        .background(LisanStyle.orange.opacity(0.025))
    }
}

struct NotesView: View {
    @ObservedObject var store: NoteStore
    let shortcut: WakeShortcut

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR VOICE, ON PAPER").font(.system(size: 9, weight: .semibold))
                        .tracking(1.8).foregroundStyle(LisanStyle.orange)
                    Text("Notes").font(.system(size: 32, weight: .semibold)).tracking(-1)
                }
                Spacer()
                if !store.notes.isEmpty {
                    Text("\(store.notes.count) \(store.notes.count == 1 ? "note" : "notes")")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.primary.opacity(0.04), in: Capsule())
                }
            }
            .padding(.horizontal, 32).padding(.top, 32).padding(.bottom, 24)

            if store.isLoading {
                Spacer()
                ProgressView("Opening your notes…").frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error = store.error {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(LisanStyle.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        }
                        if let unsaved = store.unsavedNote {
                            Text("NOT SAVED · COPY TO KEEP").font(.system(size: 10, weight: .semibold)).foregroundStyle(LisanStyle.orange)
                            NoteCard(note: unsaved)
                        }
                        if store.notes.isEmpty && store.unsavedNote == nil {
                            emptyState
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(store.notes) { note in NoteCard(note: note) }
                            }
                        }
                    }
                    .frame(maxWidth: 740).frame(maxWidth: .infinity)
                    .padding(.horizontal, 32).padding(.bottom, 26)
                }
            }
            HStack(spacing: 7) {
                Image(systemName: "waveform").foregroundStyle(LisanStyle.orange)
                Text("Hold \(shortcut.badge) anywhere. No text field? It becomes a note.")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 32).padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Divider().opacity(0.5) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "note.text")
                .font(.system(size: 29, weight: .light)).foregroundStyle(LisanStyle.orange)
                .frame(width: 76, height: 76)
                .background(LisanStyle.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 23))
                .rotationEffect(.degrees(-5))
                .padding(.bottom, 8)
            Text("Make a little room\nfor your thoughts.")
                .font(.system(size: 25, weight: .medium)).tracking(-0.6).multilineTextAlignment(.center)
            Text("Hold \(shortcut.title) and speak when no text field is focused.\nOr choose Note in the recording bar, wherever you are.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .lineSpacing(5).multilineTextAlignment(.center)
            Text("TEXT ONLY. QUIETLY KEPT.")
                .font(.system(size: 9, weight: .medium)).tracking(1.6).foregroundStyle(.tertiary).padding(.top, 10)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 65)
    }
}

struct NoteCard: View {
    let note: VoiceNote
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text(note.timestamp).font(.system(size: 10, weight: .medium)).tracking(0.7)
                    .foregroundStyle(.secondary).textSelection(.enabled)
                Spacer(minLength: 8)
                Button {
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.setString(note.text, forType: .string)
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(copied ? LisanStyle.orange : .secondary)
                        .frame(width: 28, height: 28).contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain).help(copied ? "Copied" : "Copy note")
                .accessibilityLabel(copied ? "Note copied" : "Copy note")
                .task(id: copied) {
                    guard copied else { return }
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    if !Task.isCancelled { copied = false }
                }
            }
            Text(note.text).font(.system(size: 15)).lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LisanStyle.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.025), radius: 8, y: 3)
    }
}

struct NoteDestinationSettings: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.text").font(.system(size: 19)).foregroundStyle(LisanStyle.orange)
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.destination.lastPathComponent).fontWeight(.medium)
                    Text((store.destinationPath as NSString).abbreviatingWithTildeInPath)
                        .font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Each note is appended with its local date, time, and time zone. A copy stays in Notes, even if you change files.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Menu("Choose file…") {
                    Button("Use an existing Markdown file…") { store.chooseExistingFile() }
                    Button("Create a new Markdown file…") { store.chooseNewFile() }
                }
                .fixedSize()
                if !store.usesDefaultDestination {
                    Button("Use default") { store.restoreDefault() }
                }
            }
            if let error = store.error {
                Text(error).font(.system(size: 11)).foregroundStyle(LisanStyle.orange)
            }
            if store.pendingCount > 0 {
                Divider()
                Text("\(store.pendingCount) saved \(store.pendingCount == 1 ? "note is" : "notes are") waiting to be appended. Retry uses each note’s original file.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Button(store.isRetrying ? "Retrying…" : "Retry file writes") { store.retryExports() }
                    .disabled(store.isRetrying)
            }
        }
    }
}
