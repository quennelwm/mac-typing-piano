import AppKit
import PianoCore

/// A draft-only settings window. Never captures keys or invokes an audio engine.
final class KeymapEditor: NSWindowController, NSWindowDelegate, NSTableViewDataSource {
    private let base: KeyMapping
    private let configuration: () -> CustomKeymap
    private let save: (CustomKeymap, CustomKeymap) throws -> Void
    private(set) var draft: KeymapDraft
    private let current = NSTextField(labelWithString: "")
    private let dirty = NSTextField(labelWithString: "")
    private let hint = NSTextField(wrappingLabelWithString: "")
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    let keyPopup = NSPopUpButton(), pitchPopup = NSPopUpButton()
    let saveButton = NSButton(title: "保存", target: nil, action: nil)
    private let reloadButton = NSButton(title: "重新载入", target: nil, action: nil)
    private let table = NSTableView()
    private var lastSwapSummary: String?
    private var rows: [KeyMapping.Key] = []
    init(base: KeyMapping, configuration: @escaping () -> CustomKeymap, warning: String?, save: @escaping (CustomKeymap, CustomKeymap) throws -> Void) throws {
        self.base = base; self.configuration = configuration; self.save = save
        draft = try KeymapDraft(configuration: configuration(), selectedKey: "keyG")
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 440), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "自定义键位"; window.isReleasedWhenClosed = false; window.delegate = self; window.center()
        let title = NSTextField(labelWithString: "让常用按键对应你熟悉的音高")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        let description = NSTextField(labelWithString: "选择实体键和音高，保存后生效。已占用音高会交换。")
        description.font = .systemFont(ofSize: 12)
        for key in base.keys { keyPopup.addItem(withTitle: Self.keyName(key)) }
        keyPopup.target = self; keyPopup.action = #selector(keyChanged)
        pitchPopup.target = self; pitchPopup.action = #selector(pitchChanged)
        keyPopup.setAccessibilityLabel("实体键，仅下方五排64键")
        pitchPopup.setAccessibilityLabel("目标音高，中央C为C4，MIDI60")
        let selectors = NSStackView(views: [NSTextField(labelWithString: "实体键"), keyPopup, NSTextField(labelWithString: "目标音高"), pitchPopup])
        selectors.orientation = .horizontal; selectors.spacing = 8
        keyPopup.widthAnchor.constraint(equalToConstant: 140).isActive = true
        pitchPopup.widthAnchor.constraint(equalToConstant: 235).isActive = true
        for (id, title, width) in [("key", "实体键", 190.0), ("before", "当前音高", 145.0), ("after", "保存后音高", 145.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id)); column.title = title; column.width = width; table.addTableColumn(column)
        }
        table.rowHeight = 23; table.dataSource = self; table.usesAlternatingRowBackgroundColors = true
        table.setAccessibilityLabel("保存后全部变更")
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: 145).isActive = true
        let restore = NSButton(title: "恢复新表默认", target: self, action: #selector(restoreDefault))
        let cancel = NSButton(title: "取消", target: self, action: #selector(cancel)); cancel.keyEquivalent = "\u{1b}"
        saveButton.target = self; saveButton.action = #selector(saveDraft); saveButton.keyEquivalent = "\r"
        reloadButton.target = self; reloadButton.action = #selector(reloadDraft); reloadButton.isHidden = true
        for button in [restore, cancel, saveButton, reloadButton] { button.bezelStyle = .rounded }
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [restore, spacer, reloadButton, cancel, saveButton]); buttons.spacing = 8
        hint.maximumNumberOfLines = 2; hint.preferredMaxLayoutWidth = 512
        errorLabel.maximumNumberOfLines = 2; errorLabel.preferredMaxLayoutWidth = 512
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor
        errorLabel.font = .systemFont(ofSize: 11); errorLabel.textColor = .systemRed
        errorLabel.setAccessibilityLabel("键位保存或载入提示")
        errorLabel.stringValue = warning ?? ""; errorLabel.isHidden = warning == nil
        let stack = NSStackView(views: [title, current, dirty, description, selectors, hint, scroll, errorLabel, buttons])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20), scroll.widthAnchor.constraint(equalTo: stack.widthAnchor), buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        window.initialFirstResponder = keyPopup
        keyPopup.nextKeyView = pitchPopup; pitchPopup.nextKeyView = restore; restore.nextKeyView = cancel; cancel.nextKeyView = saveButton
        update()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    static func keyName(_ key: KeyMapping.Key) -> String { key.labelParts.main == key.accessibleName ? key.displayLabel : key.labelParts.main + " · " + key.accessibleName }
    private func update() {
        let candidate = draft.candidate
        rows = base.keys.filter { candidate.notes[$0.physicalKeyID] != draft.baseline.notes[$0.physicalKeyID] }
        current.stringValue = "当前使用：" + (draft.baseline == CustomKeymap(defaultMapping: base) ? "新表默认" : "自定义键位")
        dirty.stringValue = rows.isEmpty ? "草稿：未修改" : "草稿：待保存 · \(rows.count)项变更"
        keyPopup.selectItem(at: base.keys.firstIndex { $0.physicalKeyID == draft.selectedKey } ?? 0)
        pitchPopup.removeAllItems()
        for midi in 33...96 {
            let owner = base.keys.first { draft.working.notes[$0.physicalKeyID] == midi }!
            pitchPopup.addItem(withTitle: "\(CustomKeymap.noteName(midi)) · MIDI \(midi) · \(owner.displayLabel)" + (midi == 60 ? " 中央C" : ""))
        }
        pitchPopup.selectItem(at: draft.targetMIDI - 33)
        hint.stringValue = lastSwapSummary ?? (rows.isEmpty ? "尚无变更。选择目标音高即可交换；关闭或取消不保存。" : "草稿 \(CustomKeymap.noteName(draft.targetMIDI))；下表列出全部待保存变更。")
        saveButton.isEnabled = draft.dirty
        table.reloadData()
    }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let key = rows[row]
        switch tableColumn?.identifier.rawValue {
        case "key": return Self.keyName(key)
        case "before": return CustomKeymap.noteName(draft.baseline.notes[key.physicalKeyID]!)
        default: return CustomKeymap.noteName(draft.candidate.notes[key.physicalKeyID]!)
        }
    }
    @objc func keyChanged() { try? draft.selectKey(base.keys[keyPopup.indexOfSelectedItem].physicalKeyID); update() }
    @objc func pitchChanged() {
        let target = pitchPopup.indexOfSelectedItem + 33, old = draft.targetMIDI
        let key = base.key(draft.selectedKey)!
        let other = base.keys.first { draft.candidate.notes[$0.physicalKeyID] == target }!
        try? draft.selectPitch(target)
        lastSwapSummary = target == old ? "已是此音高；草稿未改变。" : "本次交换：\(key.displayLabel) \(CustomKeymap.noteName(old))→\(CustomKeymap.noteName(target))；\(other.displayLabel) \(CustomKeymap.noteName(target))→\(CustomKeymap.noteName(old))（仅草稿）。"
        update()
    }
    @objc func restoreDefault() { draft.restoreDefault(base); lastSwapSummary = "恢复新表默认（仅草稿）；下表列出全部待保存变更。"; update() }
    @objc func cancel() { close() }
    @objc func reloadDraft() {
        if let fresh = try? KeymapDraft(configuration: configuration(), selectedKey: draft.selectedKey) { draft = fresh }
        errorLabel.isHidden = true; reloadButton.isHidden = true; lastSwapSummary = nil; update()
    }
    @objc func saveDraft() {
        guard draft.dirty else { return }
        saveButton.isEnabled = false
        do {
            guard configuration() == draft.baseline else { throw ProbeError.invalid("键位已在其他位置更新，请重新载入后调整") }
            try save(draft.candidate, draft.baseline); close()
        } catch {
            errorLabel.stringValue = "保存失败，当前键位未更改。\(error.localizedDescription)"; errorLabel.isHidden = false; errorLabel.toolTip = error.localizedDescription
            reloadButton.isHidden = configuration() == draft.baseline
            saveButton.isEnabled = configuration() == draft.baseline
        }
    }
    func savePNG(to url: URL) throws {
        guard let view = window?.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw ProbeError.invalid("设置窗口渲染失败") }
        view.layoutSubtreeIfNeeded()
        guard view.bounds.contains(view.convert(saveButton.bounds, from: saveButton)) else { throw ProbeError.invalid("设置窗口底部按钮超出画布") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        // cacheDisplay captures transparent content, not the NSWindow background.
        guard let image = bitmap.cgImage,
              let context = CGContext(data: nil, width: bitmap.pixelsWide, height: bitmap.pixelsHigh,
                bitsPerComponent: 8, bytesPerRow: bitmap.pixelsWide * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ProbeError.invalid("设置窗口位图失败")
        }
        let rect = CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        window?.effectiveAppearance.performAsCurrentDrawingAppearance {
            context.setFillColor(NSColor.windowBackgroundColor.cgColor); context.fill(rect)
        }
        context.draw(image, in: rect)
        guard let composed = context.makeImage(), let png = NSBitmapImageRep(cgImage: composed).representation(using: .png, properties: [:]) else { throw ProbeError.invalid("设置窗口PNG编码失败") }
        try png.write(to: url)
    }
}

/// Explicit diagnostic entry point: real AppKit controls, in-memory save callback, no user preferences.
public enum KeymapEditorEvidence {
    public static func render(base: KeyMapping, directory: URL) throws -> [String: Any] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var current = CustomKeymap(defaultMapping: base), allowSave = false, writes = 0
        let editor = try KeymapEditor(base: base, configuration: { current }, warning: nil) { next, _ in
            guard allowSave else { throw ProbeError.invalid("验证用写入失败；当前键位保持不变") }
            current = next; writes += 1
        }
        defer { editor.close() }
        editor.window?.orderFront(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        try editor.savePNG(to: directory.appendingPathComponent("editor-default.png"))
        editor.pitchPopup.selectItem(at: 53 - 33); editor.pitchChanged()
        try editor.savePNG(to: directory.appendingPathComponent("editor-swap-draft.png"))
        editor.saveDraft()
        try editor.savePNG(to: directory.appendingPathComponent("editor-save-failed.png"))
        guard writes == 0, editor.draft.dirty else { throw ProbeError.invalid("保存失败保护验证失败") }
        allowSave = true; editor.saveDraft()
        let restore = try KeymapEditor(base: base, configuration: { current }, warning: nil) { next, _ in current = next; writes += 1 }
        defer { restore.close() }
        restore.window?.orderFront(nil); restore.restoreDefault()
        try restore.savePNG(to: directory.appendingPathComponent("editor-restore-draft.png"))
        restore.cancel()
        guard writes == 1, current.notes["keyG"] == 53 else { throw ProbeError.invalid("取消恢复不应写入") }
        return ["kind": "production NSWindow/NSPopUpButton/NSTableView rendering", "canvasPt": [560,440],
            "images": 4, "saveFailureRetainedDraft": true, "retryCommittedOnce": true, "cancelDidNotCommitRestore": true,
            "persistenceCallback": "in-memory simulation; production filesystem is tested separately", "userPreferencesWritten": false,
            "inputStarted": false, "audioStarted": false, "systemSettingsChanged": false]
    }
}
