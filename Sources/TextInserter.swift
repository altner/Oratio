import AppKit
import CoreGraphics

enum TextInserter {
    static func paste(_ text: String, into target: NSRunningApplication?) {
        let pb = NSPasteboard.general
        let saved: [[(NSPasteboard.PasteboardType, Data)]] = (pb.pasteboardItems ?? []).map { item in
            item.types.compactMap { t in item.data(forType: t).map { (t, $0) } }
        }

        pb.clearContents()
        pb.setString(text, forType: .string)

        target?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            synthesizeCmdV()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                restoreClipboard(saved)
            }
        }
    }

    private static func restoreClipboard(_ saved: [[(NSPasteboard.PasteboardType, Data)]]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        guard !saved.isEmpty else { return }
        let items: [NSPasteboardWriting] = saved.map { entries in
            let item = NSPasteboardItem()
            for (t, d) in entries { item.setData(d, forType: t) }
            return item
        }
        pb.writeObjects(items)
    }

    private static func synthesizeCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09  // kVK_ANSI_V

        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }
}
