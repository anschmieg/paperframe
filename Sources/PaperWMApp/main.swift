import AppKit

// Entry point for the PaperWM menu-bar application.
//
// NSApplication is initialized here; the delegate handles all startup logic.
// An Info.plist with LSUIElement=YES is required for a Dock-less menu-bar app;
// this is handled at the Xcode bundle level and is out of scope for the SPM skeleton.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
