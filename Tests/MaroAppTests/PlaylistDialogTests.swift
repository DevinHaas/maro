import AppKit
import Testing
@testable import MaroApp

@Test @MainActor func playlistDialogsKeepSafeDefaultsAndEditableNames() {
    let deletion = PlaylistDialogs.deletion(title: "Quiet afternoons")
    #expect(deletion.messageText == "Do you really want to remove the playlist?")
    #expect(deletion.buttons.map(\.title) == ["Cancel", "Remove playlist"])
    #expect(deletion.buttons[0].keyEquivalent == "\r")
    #expect(deletion.buttons[1].keyEquivalent.isEmpty)
    #expect(deletion.window.initialFirstResponder === deletion.buttons[0])
    #expect(deletion.alertStyle == .warning)
    #expect(deletion.informativeText.contains("permanently deleted from YouTube"))
    #expect(deletion.informativeText.contains("Quiet afternoons"))
    for value in ["", "An existing playlist"] {
        let (alert, field) = PlaylistDialogs.name(title: "Playlist name", value: value)
        #expect(alert.buttons.map(\.title) == ["Save", "Cancel"])
        #expect(field.stringValue == value)
        #expect(field.isEditable && field.isSelectable)
        #expect(field.accessibilityLabel() == "Playlist name")
        #expect(alert.window.initialFirstResponder === field)
        #expect(alert.window.appearance?.name == .darkAqua)
    }
}
