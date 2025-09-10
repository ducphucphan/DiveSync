import UIKit

class ZoomAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    var isPresenting: Bool
    
    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.2 // Thời gian hoạt ảnh
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let view = isPresenting
                ? transitionContext.view(forKey: .to)
                : transitionContext.view(forKey: .from)
        else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        if isPresenting {
            containerView.addSubview(view)
            
            // Bắt đầu với trạng thái phóng to nhỏ và trong suốt
            view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            view.alpha = 0
        }
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration, animations: {
            if self.isPresenting {
                // Phóng to khi present
                view.transform = .identity
                view.alpha = 1
            } else {
                // Thu nhỏ và mờ dần khi dismiss
                view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                view.alpha = 0
            }
        }, completion: { finished in
            if !self.isPresenting {
                view.removeFromSuperview() // Xóa view khi dismiss
            }
            transitionContext.completeTransition(finished)
        })
    }
}
