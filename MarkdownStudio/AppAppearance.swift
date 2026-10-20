import AppKit
import SwiftUI

/// The app's Dark Mode setting, applied to every window. Stored in user defaults so it's remembered;
/// views read it with `@AppStorage(AppAppearance.key)`.
enum AppAppearance: String, CaseIterable, Identifiable {
    case dark
    case system
    case light

    static let key = "AppAppearance"

    var id: Self { self }

    var title: String {
        switch self {
        case .dark: "On"
        case .system: "System Default"
        case .light: "Off"
        }
    }

    var symbol: String {
        switch self {
        case .dark: "moon.fill"
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        }
    }

    static var current: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .system
    }

    /// A binding that also applies the appearance when it's set (menus don't run `onChange`).
    static func binding(_ storage: Binding<AppAppearance>) -> Binding<AppAppearance> {
        Binding(get: { storage.wrappedValue }, set: { value in
            storage.wrappedValue = value
            apply(value)
        })
    }

    /// Sets the appearance of the whole app, including the web views' `prefers-color-scheme`.
    static func apply(_ appearance: AppAppearance) {
        switch appearance {
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        }
    }
}

/// Applies the saved appearance before any window (including the open panel) appears.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppAppearance.apply(.current)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Give restored windows time to appear before new ones are placed by the user's choice.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            MainActor.assumeIsolated { WindowPlacement.shared.hasFinishedLaunching = true }
        }
    }
}

/// A menu for choosing Dark Mode: On, System Default or Off.
struct DarkModeMenu: View {
    @AppStorage(AppAppearance.key) private var appearance = AppAppearance.system

    var body: some View {
        Menu {
            picker
        } label: {
            Label("Dark Mode", systemImage: appearance.symbol)
        }
        .help("Dark Mode: \(appearance.title)")
    }

    var picker: some View {
        Picker("Dark Mode", selection: AppAppearance.binding($appearance)) {
            ForEach(AppAppearance.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.inline)
    }
}
