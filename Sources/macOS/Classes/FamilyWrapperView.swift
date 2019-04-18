import Cocoa

class FamilyWrapperView: NSScrollView {
  weak var parentDocumentView: FamilyDocumentView?
  var isScrolling: Bool = false
  var view: NSView
  private lazy var clipView = FamilyClipView()
  private var frameObserver: NSKeyValueObservation?
  private var alphaObserver: NSKeyValueObservation?
  private var hiddenObserver: NSKeyValueObservation?

  open override var verticalScroller: NSScroller? {
    get { return nil }
    set {}
  }

  required init(frame frameRect: NSRect, wrappedView: NSView) {
    self.view = wrappedView
    super.init(frame: frameRect)
    // Disable resizing of subviews to avoid recursion.
    // The wrapper view should follow the `.view`'s size, not the
    // otherway around. If this is set to `true` then there is
    // a potential for the observers trigger a resizing recursion.
    self.autoresizesSubviews = false
    self.contentView = clipView
    self.documentView = wrappedView
    self.hasHorizontalScroller = true
    self.hasVerticalScroller = false
    self.postsBoundsChangedNotifications = true
    self.verticalScrollElasticity = .none
    self.drawsBackground = false

    self.frameObserver = view.observe(\.frame, options: [.new, .old], changeHandler: { [weak self] (_, value) in
      guard abs(value.newValue?.size.height ?? 0) != abs(value.oldValue?.size.height ?? 0) else { return }
      if let newValue = value.newValue {
        self?.setWrapperFrameSize(newValue)
      }
      self?.layoutViews(from: value.oldValue, to: value.newValue)
    })

    self.alphaObserver = view.observe(\.alphaValue, options: [.initial, .new, .old]) { [weak self] (_, value) in
      guard value.newValue != value.oldValue, let newValue = value.newValue else { return }
      self?.alphaValue = newValue
      (self?.enclosingScrollView as? FamilyScrollView)?.cache.invalidate()
      self?.layoutViews(from: nil, to: nil)
    }

    self.hiddenObserver = view.observe(\.isHidden, options: [.initial, .new, .old]) { [weak self] (_, value) in
      guard value.newValue != value.oldValue, let newValue = value.newValue else { return }
      self?.isHidden = newValue
      (self?.enclosingScrollView as? FamilyScrollView)?.cache.invalidate()
      self?.layoutViews(from: nil, to: nil)
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidMoveToSuperview() {
    super.viewDidMoveToSuperview()
    if superview == nil { return }
    layoutViews(from: bounds, to: bounds)
  }

  override func scrollWheel(with event: NSEvent) {
    if event.scrollingDeltaX != 0.0 && view.frame.size.width > frame.size.width {
      super.scrollWheel(with: event)
    } else if event.scrollingDeltaY != 0.0 {
      nextResponder?.scrollWheel(with: event)
    }

    isScrolling = !(event.deltaX == 0 && event.deltaY == 0) ||
      !(event.phase == .ended || event.momentumPhase == .ended)
  }

  private func setWrapperFrameSize(_ rect: CGRect) {
    frame.size = rect.size
  }

  func layoutViews(from fromValue: CGRect?, to toValue: CGRect?) {
    if let fromValue = fromValue, let toValue = toValue {
      (enclosingScrollView as? FamilyScrollView)?.wrapperViewDidChangeFrame(from: fromValue, to: toValue)
      return
    }

    guard window?.inLiveResize != true, !isScrolling,
      let familyScrollView = parentDocumentView?.familyScrollView else {
        return
    }

    if NSAnimationContext.current.duration > 0.0 && !familyScrollView.layoutIsRunning {
      if view is NSCollectionView {
        let delay = NSAnimationContext.current.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          familyScrollView.layoutViews(withDuration: 0.0, force: false, completion: nil)
        }
      } else {
        familyScrollView.layoutViews(withDuration: NSAnimationContext.current.duration,
                                     force: false, completion: nil)
      }
    } else {
      familyScrollView.layoutViews(withDuration: nil, force: false, completion: nil)
    }
  }
}
