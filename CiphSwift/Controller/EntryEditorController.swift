import Cocoa

protocol EntryEditorProtocol {
  func closeEditor(forId id: Int)
  func addEntry(_ dict: NSMutableDictionary)
  func modifyEntry(_ dict: NSMutableDictionary, forId id: Int)
}

class EntryEditorController: NSWindowController, NSWindowDelegate, NSControlTextEditingDelegate, NSTextViewDelegate, NSComboBoxDataSource {
  
  let id: Int
  let model: CSDocumentModel
  let docName: String
  let delegate: EntryEditorProtocol
  
  @IBOutlet weak var nameField: NSTextField!
  @IBOutlet weak var accountField: NSTextField!
  @IBOutlet weak var passwordField: NSTextField!
  @IBOutlet weak var urlField: NSTextField!
  @IBOutlet var notesView: NSTextView!
  @IBOutlet weak var categoryField: NSComboBox!
  
  var fieldMap = [String: NSTextField]()
  
  init(forId id: Int, docName: String, model: CSDocumentModel, delegate: EntryEditorProtocol) {
    self.id = id
    self.model = model
    self.delegate = delegate
    self.docName = docName
    super.init(window: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("Not implemented")
  }
  
  override var windowNibName: NSNib.Name? {
    return NSNib.Name("EntryEditor")
  }
  
  override func windowDidLoad() {
    // Populate field map
    fieldMap["name"] = nameField
    fieldMap["account"] = accountField
    fieldMap["password"] = passwordField
    fieldMap["url"] = urlField
    fieldMap["category"] = categoryField
    
    if id >= 0 {
      let item = model.item(withId: id)
      let title = item?["name"] as? String
      if let title = title {
        window?.title = "Edit Entry Named (Filename)".localized(title, docName)
      } else {
        window?.title = "Edit Entry (Filename)".localized(docName)
      }
      
      for key in fieldMap.keys {
        fieldMap[key]?.stringValue = item?[key] as? String ?? ""
      }
      let noteLength = notesView.textStorage?.length ?? 0
      let range = NSMakeRange(0, noteLength)
      if let noteData = item?["notes"] as? Data {
        notesView.replaceCharacters(in: range, withRTFD: noteData)
      }
    } else {
      window?.title = "New Entry (Filename)".localized(docName)
    }
    
    super.windowDidLoad()
  }
  
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if window?.isDocumentEdited ?? false {
      let confirmClose = NSAlert()
      
      confirmClose.messageText = "Save Message".localized
      confirmClose.informativeText = "Discard Message".localized
      confirmClose.alertStyle = NSAlert.Style.warning
      confirmClose.addButton(withTitle: "Save Changes".localized)
      confirmClose.addButton(withTitle: "Don't Save".localized)
      confirmClose.addButton(withTitle: "Cancel".localized)
      
      confirmClose.beginSheetModal(for: window!, completionHandler: { response in
        if response == .alertThirdButtonReturn {
          // Cancel
          return
        } else if response == .alertFirstButtonReturn {
          // Save
          self.commitChanges()
        }
        // Save or Don't Save: close the sheet and window
        confirmClose.window.orderOut(self)
        self.close()
        self.delegate.closeEditor(forId: self.id)
      })
      
      return false
    } else {
      delegate.closeEditor(forId: id)
      return true
    }
  }
  
  func bringToFront() {
    showWindow(self)
    window?.makeKeyAndOrderFront(self)
  }
  
  func isEntryModified() -> Bool {
    // If it is a new entry (negative id), this will check if all fields are blank
    let item = model.item(withId: id)
    for key in fieldMap.keys {
      if (fieldMap[key]?.stringValue ?? "") != (item?[key] as? String ?? "") {
        return true
      }
    }
    
    let data = model.item(withId: id)?["notes"] as? Data
    let str = (data != nil) ? NSAttributedString(rtfd: data!, documentAttributes: nil) : NSAttributedString(string: "")
    return (notesView.textStorage ?? NSAttributedString(string: "")) != str
  }
  
  func controlTextDidChange(_ obj: Notification) {
    window?.isDocumentEdited = isEntryModified()
  }
  
  func textDidChange(_ notification: Notification) {
    window?.isDocumentEdited = isEntryModified()
  }
  
  func isCommandReturnKeyEquivalent() -> Bool {
    if let event = NSApp.currentEvent {
      if event.type == .keyDown {
        if event.modifierFlags.contains(.command) && (event.keyCode == 36 || event.keyCode == 76) {
          return true
        }
      }
    }
    return false
  }
  
  func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    if isCommandReturnKeyEquivalent() {
      save(self)
      return true
    } else if commandSelector == #selector(insertNewline(_:)) {
      textView.insertNewlineIgnoringFieldEditor(self)
      return true
    }
    return false
  }
  
  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    // If the popup menu of the category combo box is open, then swallow "insert newline" events, i.e. prevent the return key from activating the default button
    if control == categoryField {
      if categoryField.cell?.isAccessibilityExpanded() ?? false {
        if commandSelector  == #selector(insertNewline(_:)) {
          return true
        }
      }
    }
    if isCommandReturnKeyEquivalent() {
      save(self)
      return true
    }
    return false
  }
  
  func commitChanges() {
    if isEntryModified() {
      let dict = NSMutableDictionary()
      for key in fieldMap.keys {
        dict[key] = (fieldMap[key]?.stringValue ?? "")
      }
      let noteLength = notesView.textStorage?.length ?? 0
      dict["notes"] = notesView.rtfd(from: NSMakeRange(0, noteLength))
      if id >= 0 {
        delegate.modifyEntry(dict, forId: id)
      } else {
        delegate.addEntry(dict)
      }
      window?.isDocumentEdited = false
    }
  }
  
  @IBAction func save(_ sender: Any) {
    commitChanges()
    self.close()
    self.delegate.closeEditor(forId: self.id)
  }
  
  let categoryItems = ["Banking", "Email", "Internet"]
  
  func numberOfItems(in comboBox: NSComboBox) -> Int {
    return categoryItems.count
  }
  
  func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
    return categoryItems[index]
  }
}
