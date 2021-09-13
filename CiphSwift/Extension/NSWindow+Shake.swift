import Cocoa

extension NSWindow {
  func shake() {
    // https://stackoverflow.com/questions/10056528
    let numberOfShakes = 2
    let durationOfShake = 0.25
    let vigourOfShake = 0.01
    
    let shakeAnimation = CAKeyframeAnimation()
    
    let shakePath = CGMutablePath()
    shakePath.move(to: CGPoint(x: NSMinX(frame), y: NSMinY(frame)))
    
    for _ in 1...numberOfShakes {
      shakePath.addLine(to: CGPoint(x:NSMinX(frame) - frame.size.width * CGFloat(vigourOfShake), y: NSMinY(frame)))
      shakePath.addLine(to: CGPoint(x:NSMinX(frame) + frame.size.width * CGFloat(vigourOfShake), y: NSMinY(frame)))
    }
    
    shakePath.closeSubpath()
    shakeAnimation.path = shakePath
    shakeAnimation.duration = CFTimeInterval(durationOfShake)
    self.animations = ["frameOrigin": shakeAnimation]
    self.animator().setFrameOrigin(frame.origin)
  }
}
