import Cocoa

class CSDocument: NSDocument {
  
  enum State {
    case unsaved
    case unlocked
    case locked
  }
  
  enum SaveAction {
    case none
    case save
    case saveAs
    case saveTo
  }
  
  static let fields = CSFields()
  
  var state: State
  var documentWindowController: NSWindowController?
  var passphrasePrompt: PassphrasePromptController?
  var passphraseChooser: PassphraseChooserController?
  var model: CSDocumentModel
  var entryEditors = [Int: EntryEditorController]()
  var saveAction: SaveAction = .none
  
  @IBOutlet weak var table: NSTableView!
  @IBOutlet weak var searchField: NSSearchField!
  
  @IBOutlet weak var editToolbarItem: NSToolbarItem!
  @IBOutlet weak var deleteToolbarItem: NSToolbarItem!
  
  @IBOutlet weak var numberOfItemsLabel: NSTextField!
  
  var searchKey: String?
  
  override init() {
    state = .locked
    model = CSDocumentModel()
    super.init()
  }
  
  convenience init(type: String) throws {
    self.init()
    state = .unsaved
  }
  
  override class var autosavesInPlace: Bool {
    return false
  }
  
  override func makeWindowControllers() {
    documentWindowController = NSWindowController.init(windowNibName: "CSDocument", owner: self)
    // If the document is locked, we wait until the password has been entered before showing the password list
    if state != .locked {
      addWindowController(documentWindowController!)
    }
  }
  
  @IBAction func search(_ sender: Any) {
    // reloadData will clear the selection.
    // We save the selection here, and then restore as much as possible (given that some selected rows may be gone because of changes to data model or search criteria)
    let selection = table.selectedRowIndexes
    let selectedIds = selection.map { model.id(fromVisibleIndex: $0) }
    
    if let searchKey = searchKey {
      model.filter(byKey: searchKey, using: searchField.stringValue)
    } else {
      model.filter(using: searchField.stringValue)
    }
    
    table.reloadData()
    
    // Restore selection
    var idToRowIndex = [Int: Int]()
    for i in 0..<table.numberOfRows {
      idToRowIndex[model.id(fromVisibleIndex: i)] = i
    }
    var newSelection = IndexSet()
    for id in selectedIds {
      if let rowIndex = idToRowIndex[id] {
        newSelection.insert(rowIndex)
      }
    }
    table.selectRowIndexes(newSelection, byExtendingSelection: false)
    
    updateToolbarState()
    updateLabel()
  }
  
  @IBAction func setSearchKey(_ sender: Any) {
    if let menuItem = sender as? NSMenuItem {
      // Uncheck other items
      if let menu = menuItem.menu {
        for menuItem in menu.items {
          menuItem.state = .off
        }
      }
      searchKey = CSFields.byIndex(menuItem.tag)?.key
      searchField.placeholderString = menuItem.title
      menuItem.state = .on
      // May be necessary to re-do the search
      search(self)
    } else {
      searchKey = nil
    }
  }
  
  override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
    // Sort by name by default
    let columnId = table.column(withIdentifier: CSFields.byIndex(0)!.column)
    guard let sortDescriptor = table.tableColumns[columnId].sortDescriptorPrototype else { return }
    table.sortDescriptors = [sortDescriptor]
    contentsChanged()
  }
  
  override func data(ofType typeName: String) throws -> Data {
    // Commit any changes from open editors
    for (id, editor) in entryEditors {
      if id >= 0 {
        editor.commitChanges()
      }
    }
    if let dataToWrite = model.compressAndEncrypt() {
      return dataToWrite
    } else {
      throw NSError(domain: "CSErrorDomain", code: 3, userInfo: nil)
    }
  }
  
  override func read(from data: Data, ofType typeName: String) throws {
    // Not implemented
    throw NSError(domain: "CSErrorDomain", code: 2, userInfo: nil)
  }
  
  override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
    // Read from a file. Before we can open the file, the user has to enter the passphrase.
    // We display the passphrase prompt window, and wait for an open or cancel event.
    let data = fileWrapper.regularFileContents
    if let data = data {
      model.setEncryptedData(data)
      passphrasePrompt = PassphrasePromptController.init(filename: fileWrapper.filename, delegate: self)
      passphrasePrompt?.showWindow(self)
    } else {
      throw NSError(domain: "CSErrorDomain", code: 1, userInfo: nil)
    }
  }
  
  func edit(id: Int) {
    if let editor = entryEditors[id] {
      editor.bringToFront()
    } else {
      entryEditors[id] = EntryEditorController(forId: id, docName: displayName, model: model, delegate: self)
      entryEditors[id]!.bringToFront()
    }
  }
  
  @IBAction func edit(_ sender: Any) {
    let rows = table.selectedRowIndexes
    for index in rows {
      edit(id: model.id(fromVisibleIndex: index))
    }
  }
  
  @IBAction func add(_ sender: Any) {
    edit(id: -1)
  }
  
  @IBAction func delete(_ sender: Any) {
    let rows = table.selectedRowIndexes
    var ids = [Int]()
    for index in rows {
      let id = model.id(fromVisibleIndex: index)
      ids.append(id)
      
    }
    deleteEntries(withIds: ids)
  }
  
  func updateToolbarState() {
    let rows = table.selectedRowIndexes
    if rows.isEmpty {
      // Empty selection
      editToolbarItem.isEnabled = false
      deleteToolbarItem.isEnabled = false
    } else {
      editToolbarItem.isEnabled = true
      deleteToolbarItem.isEnabled = true
    }
  }
  
  @IBAction func choosePassphrase(_ sender: Any) {
    passphraseChooser = PassphraseChooserController(delegate: self)
    passphraseChooser!.presentSheet()
  }
  
  override func save(_ sender: Any?) {
    if model.key == nil {
      choosePassphrase(self)
      saveAction = .save
    } else {
      super.save(sender)
    }
  }
  
  override func saveAs(_ sender: Any?) {
    if model.key == nil {
      choosePassphrase(self)
      saveAction = .saveAs
    } else {
      super.saveAs(sender)
    }
  }
  
  override func saveTo(_ sender: Any?) {
    if model.key == nil {
      choosePassphrase(self)
      saveAction = .saveTo
    } else {
      super.saveTo(sender)
    }
  }
  
  override func save(withDelegate delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
    if model.key == nil {
      choosePassphrase(self)
      saveAction = .save
    } else {
      super.save(withDelegate: delegate, didSave: didSaveSelector, contextInfo: contextInfo)
    }
  }
  
  func updateLabel() {
    let numItems = model.numberOfItems
    let numSelected = table.numberOfSelectedRows
    var labelText = ""
    if numItems == 1 {
      labelText = numSelected == 0 ? "1 item".localized() : "1 item, 1 selected".localized()
    } else {
      if numSelected == 0 {
        labelText = "N items".localized(numItems)
      } else if numSelected == 1 {
        labelText = "N items, 1 selected".localized(numItems)
      } else {
        labelText = "N items, M selected".localized(numItems, numSelected)
      }
    }
    numberOfItemsLabel.stringValue = labelText
  }
  
  func contentsChanged() {
    search(self)
  }
}

extension CSDocument: PassphrasePromptProtocol {
  func openFile(withKey key: Data) {
    if model.decrypt(withKey: key) {
      passphrasePrompt?.close()
      passphrasePrompt = nil
      addWindowController(documentWindowController!)
      documentWindowController?.showWindow(self)
    } else {
      passphrasePrompt?.window?.shake()
    }
  }
  
  func cancelPassphrasePrompt() {
    passphrasePrompt?.close()
    close()
  }
  
  func deleteEntries(withIds ids: [Int]) {
    undoManager?.beginUndoGrouping()
    for id in ids {
      if let editor = entryEditors[id] {
        editor.close()
        entryEditors.removeValue(forKey: id)
      }
      if let item = model.item(withId: id) {
        model.delete(id: id)
        undoManager?.registerUndo(withTarget: self) { (document: CSDocument) in
          document.addEntry(item)
        }
      }
    }
    if !ids.isEmpty {
      contentsChanged()
    }
    undoManager?.endUndoGrouping()
  }
}

extension CSDocument: EntryEditorProtocol {
  func addEntry(_ dict: NSMutableDictionary) {
    let id = model.newItem(withDictionary: dict)
    undoManager?.registerUndo(withTarget: self) { (document: CSDocument) in
      document.deleteEntries(withIds: [id])
    }
    contentsChanged()
  }
  
  func modifyEntry(_ dict: NSMutableDictionary, forId id: Int) {
    if let dict = dict as? [AnyHashable: Any] {
      if let item = model.item(withId: id) {
        let previous = NSMutableDictionary(dictionary: item)
        item.setDictionary(dict)
        undoManager?.registerUndo(withTarget: self) { (document: CSDocument) in
          document.modifyEntry(previous, forId: id)
        }
        contentsChanged()
      }
    }
  }
  
  func closeEditor(forId id: Int) {
    entryEditors.removeValue(forKey: id)
  }
}

extension CSDocument: PassphraseChooserProtocol {
  func documentWindow() -> NSWindow? {
    return documentWindowController?.window
  }
  
  func cancelPassphraseChooser() {
    passphraseChooser = nil
    saveAction = .none
  }
  
  func selectPassphrase(_ passphrase: String) {
    passphraseChooser = nil
    let newKey = Data.key(fromString: passphrase)
    if newKey != model.key {
      model.key = newKey
      updateChangeCount(.changeDone)
    }
    switch saveAction {
    case .save:
      save(self)
    case .saveAs:
      saveAs(self)
    case .saveTo:
      saveTo(self)
    case .none:
      break
    }
    saveAction = .none
  }
}
