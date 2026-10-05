import AppKit
import SwiftUI

struct GlobalSearchView: View {
    @ObservedObject var app: ApplicationModel
    @FocusState private var focusedRow: Int?
    @State private var fieldFocused = false
    @StateObject private var geometry = SearchPreviewGeometry()
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.system(size: 19)).foregroundStyle(AppDesign.muted)
            GlobalSearchField(app: app, geometry: geometry, focused: $fieldFocused).frame(height: 28)
            if !app.globalQuery.isEmpty {
                Button { app.globalQuery = ""; app.focusSearch() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Clear global search")
            }
        }.padding(.horizontal, 18).frame(height: 44).background(AppDesign.raised).clipShape(Capsule())
            .tidalCapsuleBorder(focused: fieldFocused, interactive: true)
            .overlay(alignment: .top) { if app.previewOpen { preview.padding(.top, 52) } }
            .onChange(of: app.previewFocusedIndex) { focusedRow = $0 }
    }
    private var preview: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Navigate", systemImage: "arrow.up.arrow.down")
                Spacer()
                Text(app.previewFocusedIndex == nil ? "Return to search" : "Return to select").font(.system(size: 10))
            }.font(.system(size: 10)).foregroundStyle(AppDesign.muted).padding(8)
            ForEach(Array(app.previewQueries.enumerated()), id: \.offset) { index, query in
                Button { app.submitSearch(query) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "magnifyingglass").frame(width: 40)
                        Text(query).lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.left").foregroundStyle(AppDesign.muted)
                    }.padding(10).contentShape(Rectangle())
                }.buttonStyle(.plain).focusable().focused($focusedRow, equals: index)
                    .background(focusedRow == index ? AppDesign.Surface.selected : Color.clear).clipShape(RoundedRectangle(cornerRadius: 5))
                    .tidalBorder(cornerRadius: 5, focused: focusedRow == index, visible: focusedRow == index)
                    .accessibilityLabel("Search for \(query)")
            }
            if !app.previewVideos.isEmpty {
                Text(app.globalQuery.isEmpty ? "PICK UP WHERE YOU LEFT OFF" : "VIDEOS")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(AppDesign.muted).padding(.horizontal, 10).padding(.top, 8)
                ForEach(Array(app.previewVideos.enumerated()), id: \.element.id) { index, video in
                    HStack(spacing: 2) {
                        Button { app.play(video); app.closeSearch() } label: {
                            HStack(spacing: 12) {
                                LibraryArtwork(url: video.thumbnailURL, localPath: app.player.snapshot.localThumbnailPaths?[video.id], symbol: "play.fill").frame(width: 48, height: 48)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(video.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                    Text(video.creator).font(.system(size: 11)).foregroundStyle(AppDesign.muted).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "play.fill").foregroundStyle(AppDesign.green)
                            }.padding(8).contentShape(Rectangle())
                        }.buttonStyle(.plain).focusable().focused($focusedRow, equals: app.previewQueries.count + index)
                            .accessibilityLabel("Play \(video.title) by \(video.creator)")
                        AppIconButton(title: "Save \(video.title) to Favorites", symbol: "heart") { app.toggleFavorite(video) }
                        AppIconButton(title: "Add \(video.title) to playlist", symbol: "plus") { app.offerAdd(video) }
                    }.background(focusedRow == app.previewQueries.count + index ? AppDesign.Surface.selected : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .tidalBorder(cornerRadius: 5, focused: focusedRow == app.previewQueries.count + index,
                                     visible: focusedRow == app.previewQueries.count + index)
                }
            }
            if app.previewLoading {
                TrackListSkeleton(count: 3, layout: .preview, label: "Loading search suggestions", identifier: "search-preview-loading")
            }
            if let error = app.previewError {
                Text(error).font(.caption).foregroundStyle(AppDesign.Status.error).padding(10)
                Button("Retry search preview") { app.retryPreview() }.disabled(app.player.snapshot.sourceNeedsUpdate).padding(.horizontal, 10)
            } else if !app.previewLoading && app.previewVideos.isEmpty && app.previewQueries.isEmpty {
                Text(app.globalQuery.count < 2 ? "Type at least two characters to find videos." : "No matching videos. Try another search.")
                    .font(.caption).foregroundStyle(AppDesign.muted).padding(10)
            }
            if !app.globalQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { app.submitSearch() } label: {
                    HStack { Text("See all results for “\(app.globalQuery)”").lineLimit(1); Spacer(); Image(systemName: "arrow.right") }.padding(12)
                }.buttonStyle(.plain).foregroundStyle(AppDesign.muted)
            }
        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(height: min(CGFloat(app.previewQueries.count * 45 + app.previewVideos.count * 64 + (app.previewLoading ? 192 : 0) + 120), min(520, max(180, (geometry.field?.window?.contentView?.bounds.height ?? 720) - 180))))
            .background(AppDesign.raised)
            .clipShape(RoundedRectangle(cornerRadius: 8)).tidalBorder(cornerRadius: 8)
            .shadow(color: .black.opacity(0.7), radius: 18, y: 8)
            .background(SearchPreviewBounds(geometry: geometry))
            .onChange(of: focusedRow) { app.previewFocusedIndex = $0 }
    }
}

private struct GlobalSearchField: NSViewRepresentable {
    @ObservedObject var app: ApplicationModel
    let geometry: SearchPreviewGeometry
    @Binding var focused: Bool
    func makeCoordinator() -> Coordinator { Coordinator(app: app, geometry: geometry, focused: $focused) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false; field.drawsBackground = false; field.focusRingType = .none
        field.placeholderAttributedString = NSAttributedString(string: "What do you want to play?",
            attributes: [.foregroundColor: NSColor(AppDesign.Text.secondary)])
        field.textColor = NSColor(AppDesign.Text.primary)
        field.font = .systemFont(ofSize: 14); field.delegate = context.coordinator
        field.setAccessibilityLabel("Search YouTube")
        context.coordinator.field = field; context.coordinator.installMonitor()
        geometry.field = field
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != app.globalQuery { field.stringValue = app.globalQuery }
    }
    static func dismantleNSView(_ field: NSTextField, coordinator: Coordinator) { coordinator.removeMonitor() }
    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        let app: ApplicationModel
        let geometry: SearchPreviewGeometry
        weak var field: NSTextField?
        var monitor: Any?
        var suppressNextFocus = false
        let focused: Binding<Bool>
        init(app: ApplicationModel, geometry: SearchPreviewGeometry, focused: Binding<Bool>) {
            self.app = app; self.geometry = geometry; self.focused = focused
        }
        func controlTextDidBeginEditing(_ notification: Notification) {
            focused.wrappedValue = true
            if let editor = field?.currentEditor() as? NSTextView {
                editor.insertionPointColor = NSColor(AppDesign.Border.focus)
                editor.selectedTextAttributes = [.backgroundColor: NSColor(AppDesign.Surface.selected),
                                                 .foregroundColor: NSColor(AppDesign.Text.primary)]
            }
            if suppressNextFocus { suppressNextFocus = false; return }
            app.focusSearch()
        }
        func controlTextDidEndEditing(_ notification: Notification) { focused.wrappedValue = false }
        func controlTextDidChange(_ notification: Notification) { if let field { app.globalQuery = field.stringValue } }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) { app.submitSearch(); return true }
            return false
        }
        func removeMonitor() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
        func installMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
                guard let self, let field = self.field, event.window === field.window else { return event }
                if event.type == .leftMouseDown {
                    let fieldBounds = field.bounds.insetBy(dx: -55, dy: -12)
                    let inField = fieldBounds.contains(field.convert(event.locationInWindow, from: nil))
                    let inPreview = self.geometry.preview.map { $0.bounds.contains($0.convert(event.locationInWindow, from: nil)) } ?? false
                    if inField && !self.app.previewOpen { self.app.focusSearch() }
                    else if self.app.previewOpen && !inField && !inPreview { self.app.closeSearch() }
                    return event
                }
                guard self.app.previewOpen else { return event }
                switch event.keyCode {
                case 53:
                    self.suppressNextFocus = field.currentEditor() == nil
                    self.app.dismissPreview(); field.window?.makeFirstResponder(field); return nil
                case 125: self.app.movePreviewFocus(1); return nil
                case 126: self.app.movePreviewFocus(-1); return nil
                case 36, 76:
                    if field.currentEditor() != nil { self.app.submitSearch() }
                    else if self.app.previewFocusedIndex != nil { self.app.activateFocusedPreview() }
                    else { return event }
                    return nil
                default: return event
                }
            }
        }
    }
}

@MainActor private final class SearchPreviewGeometry: ObservableObject { weak var preview: NSView?; weak var field: NSTextField? }
private struct SearchPreviewBounds: NSViewRepresentable {
    let geometry: SearchPreviewGeometry
    func makeNSView(context: Context) -> NSView { let view = NSView(); geometry.preview = view; return view }
    func updateNSView(_ view: NSView, context: Context) { geometry.preview = view }
}
