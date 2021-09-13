import Foundation
import Compression

extension Data {
  func isCompressed() -> Bool {
    if count < 2 {
      return false
    }
    let firstTwoBytes = [UInt8](self[0..<2])
    let fcheck: UInt16 = firstTwoBytes.withUnsafeBytes { ptr in
      CFSwapInt16BigToHost(ptr.load(as: UInt16.self))
    }
    if self[0] & 0x0F == 8 && self[0] & 0x80 == 0 && fcheck % 31 == 0 {
      return true
    }
    return false
  }
  
  func decompress() -> Data {
    if isCompressed() {
      assert(count >= 4)
      // Extract the size of the uncompressed data from the last four bytes of the buffer, encoded as a big endian 32 bit integer
      let sizeBytes = [UInt8](self[count-4..<count])
      let uncompressedSize: UInt32 = sizeBytes.withUnsafeBytes { ptr in
        CFSwapInt32BigToHost(ptr.load(as: UInt32.self))
      }
      
      if uncompressedSize == 0 {
        return Data()
      }
      
      var uncompressedData = Data(count: Int(uncompressedSize))
      var bytesWritten = UInt(uncompressedSize)
      let compressedSize = UInt(count - 4)
      
      let zlibStatus = withUnsafeBytes { (srcBytes: UnsafeRawBufferPointer) in
        uncompressedData.withUnsafeMutableBytes { (dstBytes: UnsafeMutableRawBufferPointer) in
          uncompress(dstBytes.bindMemory(to: UInt8.self).baseAddress!,
                     &bytesWritten,
                     srcBytes.bindMemory(to: UInt8.self).baseAddress!,
                     compressedSize)
        }
      }
      assert(bytesWritten == uncompressedSize && zlibStatus == Z_OK)
      return uncompressedData
    } else {
      return self
    }
  }
  
  func compress(atLevel level: Int32 = Z_DEFAULT_COMPRESSION) -> Data {
    let uncompressedSize = UInt(count)
    let bufferLength = Int(ceil(Double(count)*1.001)) + 12 + 4
    var compressedData = Data(count: bufferLength)
    var compressedSize = UInt(bufferLength)
    
    let zlibStatus = withUnsafeBytes { (srcBytes: UnsafeRawBufferPointer) in
      compressedData.withUnsafeMutableBytes { (dstBytes: UnsafeMutableRawBufferPointer) in
        compress2(dstBytes.bindMemory(to: UInt8.self).baseAddress!,
                  &compressedSize,
                  srcBytes.bindMemory(to: UInt8.self).baseAddress!,
                  uncompressedSize,
                  level)
      }
    }
    assert(compressedSize <= bufferLength && zlibStatus == Z_OK)
    compressedData.count = Int(compressedSize + 4)
    
    var sizeBytes = [UInt8](repeating: 0, count: 4)
    sizeBytes.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
      ptr.storeBytes(of: CFSwapInt32HostToBig(UInt32(uncompressedSize)), toByteOffset: 0, as: UInt32.self)
    }
    compressedData[compressedSize..<compressedSize+4] = Data(sizeBytes)
    
    return compressedData
  }
}
