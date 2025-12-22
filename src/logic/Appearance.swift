import Cocoa

class Appearance {
    // size
    static var windowPadding = CGFloat(18)
    static var interCellPadding = CGFloat(1)
    static var intraCellPadding = CGFloat(5)
    static var appIconLabelSpacing = CGFloat(2)
    static var edgeInsetsSize = CGFloat(5)
    static var cellCornerRadius = CGFloat(10)
    static var windowCornerRadius = CGFloat(23)
    static var hideThumbnails = Bool(false)
    static var rowsCount = CGFloat(0)
    static var windowMinWidthInRow = CGFloat(0)
    static var windowMaxWidthInRow = CGFloat(0)
    static var iconSize = CGFloat(0)
    static var fontHeight = CGFloat(0)
    static var maxWidthOnScreen = CGFloat(0.8)
    static var maxHeightOnScreen = CGFloat(0.8)

    // theme
    static var material = NSVisualEffectView.Material.dark
    static var fontColor = NSColor.white
    static var indicatedIconShadowColor: NSColor? = .darkGray
    static var titleShadowColor: NSColor? = .darkGray
    static var imageShadowColor: NSColor? = .gray // for icon, thumbnail and windowless images
    static var highlightMaterial = NSVisualEffectView.Material.selection
    static var highlightFocusedAlphaValue = 1.0
    static var highlightHoveredAlphaValue = 0.8
    static var highlightFocusedBackgroundColor = NSColor.black.withAlphaComponent(0.5)
    static var highlightHoveredBackgroundColor = NSColor.black.withAlphaComponent(0.3)
    static var highlightFocusedBorderColor = NSColor.clear
    static var highlightHoveredBorderColor = NSColor.clear
    static var highlightBorderShadowColor = NSColor.clear
    static var highlightBorderWidth = CGFloat(0)
    static var enablePanelShadow = false

    // derived
    static var font: NSFont { NSFont.systemFont(ofSize: fontHeight) }

    private static var currentStyle: AppearanceStylePreference { Preferences.appearanceStyle }
    private static var currentSize: AppearanceSizePreference { Preferences.appearanceSize }
    private static var currentTheme: AppearanceThemePreference {
        if Preferences.appearanceTheme == .system {
            return NSAppearance.current.getThemeName()
        } else {
            return Preferences.appearanceTheme
        }
    }
    private static var currentVisibility: AppearanceVisibilityPreference { Preferences.appearanceVisibility }

    static func update() {
        updateSize()
        updateTheme()
    }

    private static func updateSize() {
        let isHorizontalScreen = NSScreen.preferred.isHorizontal()
        maxWidthOnScreen = AppearanceTestable.comfortableWidth(NSScreen.preferred.physicalSize().map { $0.width })
        if currentStyle == .appIcons {
            appIconsSize()
        } else if currentStyle == .titles {
            titlesSize(isHorizontalScreen)
        } else {
            thumbnailsSize(isHorizontalScreen)
        }
    }

    private static func updateTheme() {
        if currentTheme == .dark {
            darkTheme()
        } else {
            lightTheme()
        }
    }
    /// These three functions - thumbnailsSize(), appIconsSize(), and titlesSize() - are responsible
    /// for configuring the visual appearance settings based on the selected display mode of the app
    /// switcher.

    private static func thumbnailsSize(_ isHorizontalScreen: Bool) {
        hideThumbnails = false
        windowPadding = 10
        cellCornerRadius = 0
        windowCornerRadius = 0
        intraCellPadding = 5
        // IMPORTANT: no gaps between adjacent cells otherwise we get a small flicker as the mouse
        // moves and hovers from one thumbnail to the next where momentarily we show no app preview
        // rather than cleanly switching between showing one and the next
        interCellPadding = 0
        edgeInsetsSize = 12
        // They totally bombed the preferences and configurability of this in one of the 2024
        // updates taking away all of the sliders where you used to be able to set these settings
        // directly and instead replacing them with a small medium large setting
        let defaultRows = isHorizontalScreen ? 4 : 5
        let preferredRows = max(1, min(Preferences.thumbnailsRowsCount, 8))
        rowsCount = CGFloat(preferredRows)
        iconSize = 22
        fontHeight = 14
        maxWidthOnScreen = 0.6
        windowMinWidthInRow = 0.15
        windowMaxWidthInRow = 0.30
        // Keep row height stable; adjust total panel height via rowsCount.
        let baseMaxHeightOnScreen = CGFloat(0.8)
        let baseMaxThumbnailsHeight = NSScreen.preferred.frame.height * baseMaxHeightOnScreen - windowPadding * 2
        let baseRowHeight = ((baseMaxThumbnailsHeight - interCellPadding) / CGFloat(defaultRows) - interCellPadding).rounded()
        let targetMaxThumbnailsHeight = (baseRowHeight + interCellPadding) * rowsCount + interCellPadding
        let targetMaxHeightOnScreen = (targetMaxThumbnailsHeight + windowPadding * 2) / NSScreen.preferred.frame.height
        maxHeightOnScreen = min(targetMaxHeightOnScreen, 0.95)
        if currentVisibility == .highest {
            edgeInsetsSize = 10
            cellCornerRadius = 12
        }
    }

    private static func appIconsSize() {
        hideThumbnails = true
        windowPadding = 25
        cellCornerRadius = 10
        windowCornerRadius = 23
        edgeInsetsSize = 5
        windowMinWidthInRow = 0.04
        windowMaxWidthInRow = 0.3
        rowsCount = 1
        switch currentSize {
            case .small:
                iconSize = 88
                fontHeight = 13
            case .medium:
                iconSize = 128
                fontHeight = 15
            case .large:
                windowPadding = 28
                iconSize = 168
                fontHeight = 17
        }
    }

    private static func titlesSize(_ isHorizontalScreen: Bool) {
        hideThumbnails = true
        windowPadding = 18
        cellCornerRadius = 10
        windowCornerRadius = 23
        edgeInsetsSize = 7
        maxWidthOnScreen = isHorizontalScreen ? 0.6 : 0.8
        windowMinWidthInRow = 0.6
        windowMaxWidthInRow = 0.9
        rowsCount = 1
        switch currentSize {
            case .small:
                iconSize = 20
                fontHeight = 13
            case .medium:
                iconSize = 26
                fontHeight = 14
            case .large:
                iconSize = 32
                fontHeight = 16
        }
    }

    private static func lightTheme() {
        fontColor = .black.withAlphaComponent(0.8)
        titleShadowColor = nil
        indicatedIconShadowColor = nil
        imageShadowColor = .lightGray.withAlphaComponent(0.4)
        highlightMaterial = .mediumLight
        switch currentVisibility {
            case .normal:
                material = .light
                highlightFocusedBackgroundColor = .lightGray.withAlphaComponent(0.7)
                highlightHoveredBackgroundColor = .lightGray.withAlphaComponent(0.5)
                enablePanelShadow = false
                highlightFocusedAlphaValue = 1.0
                highlightHoveredAlphaValue = 0.8
                highlightFocusedBorderColor = NSColor.clear
                highlightHoveredBorderColor = NSColor.clear
                highlightBorderShadowColor = NSColor.clear
                highlightBorderWidth = 0
            case .high:
                material = .mediumLight
                highlightFocusedBackgroundColor = .lightGray.withAlphaComponent(0.7)
                highlightHoveredBackgroundColor = .lightGray.withAlphaComponent(0.5)
                enablePanelShadow = true
                highlightFocusedAlphaValue = 1.0
                highlightHoveredAlphaValue = 0.8
                highlightFocusedBorderColor = .lightGray.withAlphaComponent(0.9)
                highlightHoveredBorderColor = .lightGray.withAlphaComponent(0.8)
                highlightBorderShadowColor = .black.withAlphaComponent(0.5)
                highlightBorderWidth = 1
            case .highest:
                material = .mediumLight
                highlightFocusedBackgroundColor = .lightGray.withAlphaComponent(0.4)
                highlightHoveredBackgroundColor = .lightGray.withAlphaComponent(0.3)
                enablePanelShadow = true
                highlightFocusedAlphaValue = 0.4
                highlightHoveredAlphaValue = 0.2
                highlightFocusedBorderColor = NSColor.systemAccentColor
                highlightHoveredBorderColor = NSColor.systemAccentColor.withAlphaComponent(0.8)
                highlightBorderShadowColor = .black.withAlphaComponent(0.5)
                highlightBorderWidth = currentStyle == .titles ? 2 : 4
        }
    }

    private static func darkTheme() {
        fontColor = .white.withAlphaComponent(0.9)
        indicatedIconShadowColor = .darkGray
        titleShadowColor = .darkGray
        highlightMaterial = .ultraDark
        switch currentVisibility {
            case .normal:
                material = .dark
                imageShadowColor = .gray.withAlphaComponent(0.8)
                highlightFocusedBackgroundColor = .black.withAlphaComponent(0.6)
                highlightHoveredBackgroundColor = .black.withAlphaComponent(0.5)
                enablePanelShadow = false
                highlightFocusedAlphaValue = 1.0
                highlightHoveredAlphaValue = 0.8
                highlightFocusedBorderColor = NSColor.clear
                highlightHoveredBorderColor = NSColor.clear
                highlightBorderShadowColor = NSColor.clear
                highlightBorderWidth = 0
            case .high:
                material = .ultraDark
                imageShadowColor = .gray.withAlphaComponent(0.4)
                highlightFocusedBackgroundColor = .gray.withAlphaComponent(0.6)
                highlightHoveredBackgroundColor = .gray.withAlphaComponent(0.4)
                enablePanelShadow = true
                highlightFocusedAlphaValue = 1.0
                highlightHoveredAlphaValue = 0.8
                highlightFocusedBorderColor = .gray.withAlphaComponent(0.8)
                highlightHoveredBorderColor = .gray.withAlphaComponent(0.7)
                highlightBorderShadowColor = .white.withAlphaComponent(0.5)
                highlightBorderWidth = 1
            case .highest:
                material = .ultraDark
                imageShadowColor = .gray.withAlphaComponent(0.4)
                highlightFocusedBackgroundColor = .black.withAlphaComponent(0.4)
                highlightHoveredBackgroundColor = .black.withAlphaComponent(0.2)
                enablePanelShadow = true
                highlightFocusedAlphaValue = 0.4
                highlightHoveredAlphaValue = 0.2
                highlightFocusedBorderColor = NSColor.systemAccentColor
                highlightHoveredBorderColor = NSColor.systemAccentColor.withAlphaComponent(0.8)
                highlightBorderShadowColor = .white.withAlphaComponent(0.5)
                highlightBorderWidth = currentStyle == .titles ? 2 : 4
        }
    }
}
