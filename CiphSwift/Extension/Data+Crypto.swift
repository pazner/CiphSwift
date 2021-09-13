import Foundation
import CommonCrypto

extension Data {
  func sha1() -> Data {
    let len = Int(CC_SHA1_DIGEST_LENGTH)
    var digest = Data(count: len)
    withUnsafeBytes { (dataBytes: UnsafeRawBufferPointer) in
      digest.withUnsafeMutableBytes { (digestBytes: UnsafeMutableRawBufferPointer) in
        let digestPtr = digestBytes.bindMemory(to: UInt8.self).baseAddress
        CC_SHA1(dataBytes.baseAddress, CC_LONG(count), digestPtr)
      }
    }
    return digest
  }
  
  func decrypt(withKey key: Data, iv: Data? = nil, options: CCOptions = CCOptions(kCCOptionPKCS7Padding)) -> (CCCryptorStatus, Data) {
    return BlowfishCryptOperation(
      operation: CCOperation(kCCDecrypt),
      dataIn: self,
      key: key,
      options: options,
      iv: iv
    )
  }
  
  func encrypt(withKey key: Data, iv: Data? = nil, options: CCOptions = CCOptions(kCCOptionPKCS7Padding)) -> (CCCryptorStatus, Data) {
    return BlowfishCryptOperation(
      operation: CCOperation(kCCEncrypt),
      dataIn: self,
      key: key,
      options: options,
      iv: iv
    )
  }
  
  static func key(fromString str: String) -> Data {
    var passphraseData = Data(count: 2)
    // Hard-code UTF-16 big endian byte order mark
    passphraseData[0] = 0xFE
    passphraseData[1] = 0xFF
    passphraseData.append(str.data(using: .utf16BigEndian)!)
    let length = passphraseData.count
    
    // Split passphrase into two, then append SHA1 hashes to create key
    var key = passphraseData[0..<length/2].sha1()
    key.append(passphraseData[length/2..<length].sha1())
    return key
  }
}

func BlowfishCryptOperation(operation: CCOperation,
                            dataIn: Data,
                            key: Data,
                            options: CCOptions = CCOptions(kCCOptionPKCS7Padding),
                            iv: Data? = nil ) -> (CCCryptorStatus, Data) {
  if let iv = iv {
    assert(iv.count == kCCBlockSizeBlowfish)
  }
  let capacity: Int = ((dataIn.count + kCCBlockSizeBlowfish)/kCCBlockSizeBlowfish)*kCCBlockSizeBlowfish
  var dataOut = Data(count: capacity)
  var dataOutMoved: Int = 0
  
  let status = dataOut.withUnsafeMutableBytes { (dataOutBytes: UnsafeMutableRawBufferPointer) -> CCCryptorStatus in
    dataIn.withUnsafeBytes { (dataInBytes: UnsafeRawBufferPointer) -> CCCryptorStatus in
      key.withUnsafeBytes { (keyBytes: UnsafeRawBufferPointer) -> CCCryptorStatus in
        let doCrypt = { (ivBytes: UnsafeRawPointer?) in
          CCCrypt(
            operation,
            CCAlgorithm(kCCAlgorithmBlowfish),
            options,
            keyBytes.baseAddress,
            key.count,
            ivBytes,
            dataInBytes.baseAddress,
            dataIn.count,
            dataOutBytes.baseAddress,
            capacity,
            &dataOutMoved
          )
        }
        if let iv = iv {
          return iv.withUnsafeBytes { doCrypt($0.baseAddress) }
        } else {
          return doCrypt(nil)
        }
      }
    }
  }
  dataOut.count = dataOutMoved
  return (status, dataOut)
}
