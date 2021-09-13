import Cocoa

protocol PassphraseChooserProtocol {
  func documentWindow() -> NSWindow?
  func cancelPassphraseChooser()
  func selectPassphrase(_ passphrase: String)
}

class PassphraseChooserController: NSWindowController {
  
  let delegate: PassphraseChooserProtocol
  
  @IBOutlet weak var passphraseField: NSSecureTextField!
  @IBOutlet weak var confirmField: NSSecureTextField!
  @IBOutlet weak var showPassphrase: NSButton!
  @IBOutlet weak var cleartextPassphraseField: NSTextField!
  @IBOutlet weak var cleartextConfirmField: NSTextField!
  @IBOutlet weak var statusText: NSTextField!
  
  // These are bound to both the secure and cleartext fields using Cocoa bindings
  @objc dynamic var passphraseValue: String!
  @objc dynamic var confirmValue: String!
  
  init(delegate: PassphraseChooserProtocol) {
    self.delegate = delegate
    super.init(window: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("Not implemented")
  }
  
  func presentSheet() {
    if let window = window {
      statusText.stringValue = ""
      delegate.documentWindow()?.beginSheet(window, completionHandler: sheetCompleted(_:))
    }
  }
  
  func sheetCompleted(_ response: NSApplication.ModalResponse) {
    if response == .OK {
      delegate.selectPassphrase(passphraseValue)
    } else {
      delegate.cancelPassphraseChooser()
    }
  }
  
  @IBAction func toggleShowPassphrase(_ sender: Any) {
    let cleartext = (showPassphrase.state == .on)
    passphraseField.isHidden = cleartext
    confirmField.isHidden = cleartext
    cleartextPassphraseField.isHidden = !cleartext
    cleartextConfirmField.isHidden = !cleartext
  }
  
  @IBAction func cancel(_ sender: Any) {
    guard let window = window else { return }
    delegate.documentWindow()?.endSheet(window, returnCode: .cancel)
  }
  
  @IBAction func select(_ sender: Any) {
    guard let window = window else { return }
    
    let match = (passphraseValue == confirmValue)
    let empty = (passphraseValue == "" || passphraseValue == nil)
    
    if empty {
      statusText.stringValue = "Empty Passphrase".localized
    }
    if !match {
      statusText.stringValue = "Non-matching Passphrase".localized
    }
    
    if !match || empty {
      window.shake()
    } else {
      delegate.documentWindow()?.endSheet(window, returnCode: .OK)
    }
  }
  
  override var windowNibName: NSNib.Name? {
    return NSNib.Name("PassphraseChooser")
  }
  
  override func windowDidLoad() {
    super.windowDidLoad()
  }
}
