import Foundation

extension String {
  var localized: String {
    get { return NSLocalizedString(self, comment: "") }
  }
  
  func localized(_ arguments: CVarArg...) -> String {
    String(format: localized, arguments: arguments)
  }
}
