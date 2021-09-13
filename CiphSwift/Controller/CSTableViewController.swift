import Cocoa

class CSTableViewController: NSViewController {
  
  @IBOutlet weak var document: CSDocument!
  @IBOutlet weak var table: NSTableView!
  var model: CSDocumentModel?
  
  static let enterChar = Character(Unicode.Scalar(NSEnterCharacter)!)
  static let returnChar = Character(Unicode.Scalar(NSCarriageReturnCharacter)!)
  static let deleteChar = Character(Unicode.Scalar(NSDeleteCharacter)!)
  
  override func viewDidLoad() {
    super.viewDidLoad()
    model = document.model
    table.registerForDraggedTypes([.csEntry])
    table.reloadData()
  }
  
  // Handle enter/return to edit the selected item, delete to delete.
  override func keyDown(with event: NSEvent) {
    if let chars = event.characters {
      let keyChar = chars.first
      if let keyChar = keyChar {
        if keyChar == CSTableViewController.enterChar || keyChar == CSTableViewController.returnChar {
          document.edit(self)
          return
        } else if keyChar == CSTableViewController.deleteChar {
          document.delete(self)
          return
        }
      }
    }
    super.keyDown(with: event)
  }
  
  // Paste items from the given pasteboard into the current document, returning true if any new items were added, false otherwise.
  // This is used for copy & paste and drag & drop operations.
  @discardableResult func pasteItems(fromPasteboard pb: NSPasteboard) -> Bool {
    var modified = false
    if let pbItems = pb.readObjects(forClasses: [CSEntryPasteboardItem.self], options: nil) {
      for item in pbItems {
        if let item = (item as? CSEntryPasteboardItem)?.item {
          modified = true
          document.addEntry(item)
        }
      }
    }
    return modified
  }
}

extension CSTableViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    if let items = model?.visibleItem(atIndex: row) {
      guard let field = CSFields.byColumn(tableColumn?.identifier) else { return nil }
      let cellView = tableView.makeView(withIdentifier: field.cell, owner: self) as? NSTableCellView
      let stringValue = items[field.key] as? String
      
      if let cellView = cellView, let stringValue = stringValue {
        cellView.textField?.stringValue = stringValue
        return cellView
      }
    }
    return nil
  }
  
  func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
    guard let sortDescriptor = tableView.sortDescriptors.first else { return }
    model?.sort(using: sortDescriptor)
    table.reloadData()
  }
  
  func tableViewSelectionDidChange(_ notification: Notification) {
    document.updateLabel()
    document.updateToolbarState()
  }
}

extension CSTableViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    return model?.numberOfVisibleItems ?? 0
  }
  
  // Drag and drop
  func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
    return CSEntryPasteboardItem(model?.visibleItem(atIndex: row))
  }
  
  func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
    if info.draggingSource as? NSTableView != table {
      table.setDropRow(-1, dropOperation: .on)
      return .copy
    }
    return []
  }
  
  func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
    return pasteItems(fromPasteboard: info.draggingPasteboard)
  }
}

// Copy and paste
extension CSTableViewController: NSUserInterfaceValidations {
  @IBAction func copy(_ sender: AnyObject?) {
    var items = [CSEntryPasteboardItem]()
    for index in table.selectedRowIndexes {
      if let item = model?.visibleItem(atIndex: index) {
        items.append(CSEntryPasteboardItem(item))
      }
    }
    let pb = NSPasteboard.general
    pb.clearContents()
    NSPasteboard.general.writeObjects(items)
  }
  
  @IBAction func copyPassword(_ sender: Any) {
    if let item = model?.visibleItem(atIndex: table.selectedRow) {
      let pb = NSPasteboard.general
      pb.clearContents()
      pb.writeObjects([item["password"] as? NSString ?? ""])
    }
  }
  
  @IBAction func paste(_ sender: AnyObject?) {
    pasteItems(fromPasteboard: NSPasteboard.general)
  }
  
  @IBAction func cut(_ sender: AnyObject?) {
    copy(sender)
    document.delete(self)
  }
  
  func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
    switch item.action {
    case #selector(copy(_:)), #selector(cut(_:)):
      return table.numberOfSelectedRows != 0
    case #selector(paste(_:)):
      return true
    case #selector(copyPassword(_:)):
      return table.numberOfSelectedRows == 1
    default:
      return false
    }
  }
}
