import UIKit

extension UILabel {
    private static var textInsetsKey: UInt8 = 0

    /// テキストインセット
    var textInsets: UIEdgeInsets {
        get {
            return objc_getAssociatedObject(self, &UILabel.textInsetsKey) as? UIEdgeInsets ?? .zero
        }
        set {
            objc_setAssociatedObject(self, &UILabel.textInsetsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setNeedsDisplay()
        }
    }

    override open var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }
}
