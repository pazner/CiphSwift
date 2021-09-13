import Cocoa

protocol PassphrasePromptProtocol {
  func openFile(withKey: Data)
  func cancelPassphrasePrompt()
}

class PassphrasePromptController: NSWindowController, NSWindowDelegate {
  
  var delegate: PassphrasePromptProtocol
  @IBOutlet weak var label: NSTextField!
  @IBOutlet weak var passphraseField: NSSecureTextField!
  
  init(filename: String?, delegate: PassphrasePromptProtocol) {
    self.delegate = delegate
    super.init(window: nil)
    
    if let filename = filename {
      window?.title = "Enter Passphrase for Filename".localized(filename)
      label.stringValue = "Enter Passphrase Protecting Filename".localized(filename)
    } else {
      window?.title = "Enter Passphrase"
      label.stringValue = "Enter Passphrase Protecting".localized
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("Not implemented")
  }
  
  override var windowNibName: NSNib.Name? {
    return NSNib.Name("PassphrasePrompt")
  }
  
  override func windowDidLoad() {
    super.windowDidLoad()
  }
  
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    delegate.cancelPassphrasePrompt()
    return false
  }
  
  @IBAction func cancel(_ sender: Any) {
    delegate.cancelPassphrasePrompt()
  }
  
  @IBAction func open(_ sender: Any) {
    let passphrase = passphraseField.stringValue
    let key = Data.key(fromString: passphrase)
    delegate.openFile(withKey: key)
  }
}
