import Foundation
import Cocoa
import CommonCrypto

class CSDocumentModel {
  var iv: Data?
  var encryptedData: Data?
  var key: Data?
  var items = [Int: NSMutableDictionary]()
  var itemIncrementer = 0
  var visibleItemIds = [Int]()
  var sortingDescriptor: NSSortDescriptor?
  
  func arrayFromItems() -> NSMutableArray? {
    let array = NSMutableArray.init(capacity: items.count)
    var idx = 0
    for val in items.values {
      array[idx] = val
      idx += 1
    }
    return array
  }
  
  func setItems(fromArray array: NSMutableArray) {
    itemIncrementer = array.count
    items = [Int: NSMutableDictionary](minimumCapacity: itemIncrementer)
    for i in 0..<itemIncrementer {
      if let val = array[i] as? NSMutableDictionary {
        items[i] = val
      }
    }
  }
  
  func setEncryptedData(_ data: Data) {
    let ivSize = kCCBlockSizeBlowfish
    iv = data[0..<ivSize]
    encryptedData = data[ivSize..<data.count]
  }
  
  func decrypt(withKey key: Data) -> Bool {
    if encryptedData != nil {
      let (status, compressedData) = encryptedData!.decrypt(withKey: key, iv: iv)
      if status != kCCSuccess {
        return false
      }
      
      let data = compressedData.decompress()
      
      // Have to use NSUnarchiver here instead of NSKeyedUnarchiver for backwards compatibility with CiphSafe
      let itemsArray = NSUnarchiver.unarchiveObject(with: data) as? NSMutableArray
      
      if let itemArray = itemsArray {
        setItems(fromArray: itemArray)
        setAllVisible()
        encryptedData = nil
        self.key = key
        return true
      }
    }
    return false
  }
  
  func compressAndEncrypt() -> Data? {
    let itemsArray = arrayFromItems()
    // Have to use NSArchiver here instead of NSKeyedArchiver for backwards compatibility with CiphSafe
    let itemData = NSArchiver.archivedData(withRootObject: itemsArray as Any)
    let compressedData = itemData.compress()
    guard let key = key else { return nil }
    
    let ivSize = kCCBlockSizeBlowfish
    var ivBytes = [UInt8](repeating: 0, count: ivSize)
    let status = SecRandomCopyBytes(kSecRandomDefault, ivBytes.count, &ivBytes)
    if status != errSecSuccess { return nil }
    let iv = Data(bytes: &ivBytes, count: ivSize)
    
    let (cryptStatus, encryptedData) = compressedData.encrypt(withKey: key, iv: iv)
    if cryptStatus != kCCSuccess {
      return nil
    } else {
      var ivAndData = Data(capacity: ivSize + encryptedData.count)
      ivAndData.append(iv)
      ivAndData.append(encryptedData)
      return ivAndData
    }
  }
  
  var numberOfItems: Int {
    get { return items.count }
  }
  
  var numberOfVisibleItems: Int {
    get { return visibleItemIds.count }
  }
  
  func id(fromVisibleIndex index: Int) -> Int {
    return visibleItemIds[index]
  }
  
  func item(withId id: Int) -> NSMutableDictionary? {
    return items[id]
  }
  
  func delete(id: Int) {
    items.removeValue(forKey: id)
  }
  
  func delete(ids: [Int]) {
    for id in ids {
      delete(id: id)
    }
  }
  
  func newItem(withDictionary dict: NSMutableDictionary) -> Int {
    let id = itemIncrementer
    items[id] = dict
    itemIncrementer += 1
    return id
  }
  
  func visibleItem(atIndex index: Int) -> NSMutableDictionary? {
    if index >= visibleItemIds.count {
      // Warning: should never happen
      return nil
    }
    return items[visibleItemIds[index]]
  }
  
  func sort() {
    if let sortingDescriptor = sortingDescriptor {
      visibleItemIds.sort(by: {
        sortingDescriptor.compare(items[$0] as Any, to: items[$1] as Any) == ComparisonResult.orderedAscending
      })
    }
  }
  
  func sort(using descriptor: NSSortDescriptor) {
    sortingDescriptor = descriptor
    sort()
  }
  
  func setAllVisible() {
    visibleItemIds = [Int](items.keys)
    sort()
  }
  
  func filter(withPredicate predicate: (Any) -> Bool) {
    visibleItemIds.removeAll()
    for (id, item) in items {
      if predicate(item) {
        visibleItemIds.append(id)
      }
    }
    sort()
  }
  
  // Does the given entry contain the search string in the given key.
  // First try to interpret the value as a String, and if that fails, interpret the value as RTFD data (for the notes field).
  func entry(_ entry: NSMutableDictionary, containsString searchString: String, inKey key: String) -> Bool {
    if let value = entry[key] as? String {
      return value.localizedCaseInsensitiveContains(searchString)
    } else if let data = entry[key] as? Data {
      if let value = NSAttributedString(rtfd: data, documentAttributes: nil) {
        return value.string.localizedCaseInsensitiveContains(searchString)
      }
    }
    return false
  }
  
  func filter(byKey key: String, using filterValue: String) {
    if filterValue.isEmpty {
      setAllVisible()
    } else {
      filter(withPredicate: { item in
        guard let dict = item as? NSMutableDictionary else { return false }
        return entry(dict, containsString: filterValue, inKey: key)
      })
    }
  }
  
  // Filter according to any of the keys
  func filter(using filterValue: String) {
    if filterValue.isEmpty {
      setAllVisible()
    } else {
      filter(withPredicate: { item in
        guard let dict = item as? NSMutableDictionary else { return false }
        for key in dict.keyEnumerator().allObjects {
          if let key = key as? String {
            if entry(dict, containsString: filterValue, inKey: key) {
              return true
            }
          }
        }
        return false
      })
    }
  }
}

struct CSField {
  var column: NSUserInterfaceItemIdentifier
  var cell: NSUserInterfaceItemIdentifier
  var key: String
  
  init(withKey key: String) {
    self.key = key
    column = NSUserInterfaceItemIdentifier(key + "Column")
    cell = NSUserInterfaceItemIdentifier(key + "Cell")
  }
}

struct CSFields {
  static let fields = [
    CSField(withKey: "name"),
    CSField(withKey: "account"),
    CSField(withKey: "password"),
    CSField(withKey: "url"),
    CSField(withKey: "category"),
    CSField(withKey: "notes")
  ]
  
  static func byIndex(_ index: Int) -> CSField? {
    if index < 0 || index >= fields.count { return nil }
    return fields[index]
  }
  
  static func byColumn(_ column: NSUserInterfaceItemIdentifier?) -> CSField? {
    guard let column = column else { return nil }
    return fields.first { field in
      field.column == column
    }
  }
  
  static func byKey(_ key: String) -> CSField? {
    return fields.first { field in
      field.key == key
    }
  }
}

class CSEntryPasteboardItem: NSObject, NSPasteboardWriting, NSPasteboardReading {
  var item: NSMutableDictionary?
  
  required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
    if let data = propertyList as? Data {
      self.item = try? PropertyListSerialization.propertyList(from: data, format: nil) as? NSMutableDictionary
    }
  }
  
  init(_ item: NSMutableDictionary?) {
    self.item = item
  }
  
  func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
    return [.csEntry, .string]
  }
  
  func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
    guard let item = item else { return nil }
    switch type {
    case .csEntry:
      return try? PropertyListSerialization.data(fromPropertyList: item, format: .xml, options: 0)
    case .string:
      let textItem = NSMutableDictionary(dictionary: item)
      let notesData = textItem["notes"] as? Data
      let notes = (notesData != nil) ? NSAttributedString(rtfd: notesData!, documentAttributes: nil) : NSAttributedString(string: "")
      textItem["notes"] = notes?.string ?? ""
      return try? PropertyListSerialization.data(fromPropertyList: textItem, format: .xml, options: 0)
    default:
      return nil
    }
  }
  
  static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
    return [.csEntry]
  }
}

extension NSPasteboard.PasteboardType {
  static let csEntry = NSPasteboard.PasteboardType("ciphswift.entry")
}
