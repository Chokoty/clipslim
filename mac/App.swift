import AppKit
import Foundation
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var timer: Timer?
  private var ignoreChange = 0
  private var lastChange = 0
  private var lastStatus = "복사하면 WebP로 바꿉니다"
  private var lastSourceName: String?
  private var lastFile: URL?
  private var converting = false
  private var convertGen = 0
  private let toast = Toast()

  private let onKey = "webp-paste.on"
  private let notifyKey = "webp-paste.notify"

  private var isOn: Bool {
    get {
      if UserDefaults.standard.object(forKey: onKey) == nil { return true }
      return UserDefaults.standard.bool(forKey: onKey)
    }
    set { UserDefaults.standard.set(newValue, forKey: onKey) }
  }

  private var isNotify: Bool {
    get {
      if UserDefaults.standard.object(forKey: notifyKey) == nil { return true }
      return UserDefaults.standard.bool(forKey: notifyKey)
    }
    set { UserDefaults.standard.set(newValue, forKey: notifyKey) }
  }

  private var format: OutputFormat {
    get { OutputFormat.stored() }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: OutputFormat.defaultsKey) }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    ignoreChange = NSPasteboard.general.changeCount
    lastChange = ignoreChange
    lastStatus = "복사하면 \(format.label)로 바꿉니다"
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let btn = statusItem.button {
      btn.image = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: "clipslim")
      btn.image?.isTemplate = true
    }
    rebuildMenu()
    timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
      self?.tick()
    }
    RunLoop.main.add(timer!, forMode: .common)
  }

  private func tick() {
    let pb = NSPasteboard.general
    let count = pb.changeCount
    if count == lastChange { return }
    lastChange = count
    if !isOn { return }
    if count == ignoreChange { return }
    if converting { return }

    let cache: URL
    do { cache = try Converter.cacheDir() } catch {
      fail("실패: 캐시 폴더")
      return
    }

    switch Converter.action(for: pb, cacheDir: cache, format: format) {
    case .skip:
      return
    case .convertFile(let url):
      startConvert(file: url, pb: pb, gen: count)
    case .convertPasteboard:
      startConvert(file: nil, pb: pb, gen: count)
    }
  }

  private func startConvert(file: URL?, pb: NSPasteboard, gen: Int) {
    converting = true
    convertGen += 1
    let myGen = convertGen
    let format = self.format
    let original = Converter.originalByteCount(pb: pb, file: file)
    let sourceName = file?.lastPathComponent
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      defer {
        DispatchQueue.main.async { self?.converting = false }
      }
      do {
        let image = try Converter.loadCGImage(file: file, pb: pb)
        let data = try Converter.encode(cg: image, format: format)
        DispatchQueue.main.async {
          guard let self, myGen == self.convertGen else { return }
          if NSPasteboard.general.changeCount != gen { return }
          do {
            let url = try Converter.writeTemp(data, format: format)
            Converter.putFileOnPasteboard(url)
            self.ignoreChange = NSPasteboard.general.changeCount
            self.lastChange = self.ignoreChange
            self.lastFile = url
            self.lastSourceName = sourceName
            let saved = original > 0 ? 1 - Double(data.count) / Double(original) : 0
            let delta = saved > 0 ? " (−\(Int((saved * 100).rounded()))%)" : ""
            self.lastStatus = "\(Converter.bytes(original)) → \(Converter.bytes(data.count)) \(format.label)\(delta)"
            self.rebuildMenu()
            if self.isNotify {
              let text = sourceName.map { "\($0)\n\(self.lastStatus)" } ?? self.lastStatus
              self.toast.show(text)
            }
          } catch {
            self.fail("실패: \(error.localizedDescription)")
          }
        }
      } catch {
        DispatchQueue.main.async {
          guard let self, myGen == self.convertGen else { return }
          self.fail("실패: \(error.localizedDescription)")
        }
      }
    }
  }

  private func rebuildMenu() {
    let menu = NSMenu()
    let toggle = NSMenuItem(title: "변환", action: #selector(toggleOn), keyEquivalent: "")
    toggle.state = isOn ? .on : .off
    toggle.target = self
    menu.addItem(toggle)

    let notifyItem = NSMenuItem(title: "알림", action: #selector(toggleNotify), keyEquivalent: "")
    notifyItem.state = isNotify ? .on : .off
    notifyItem.target = self
    menu.addItem(notifyItem)

    let formatMenu = NSMenu()
    for f in OutputFormat.allCases {
      let item = NSMenuItem(title: f.label, action: #selector(pickFormat(_:)), keyEquivalent: "")
      item.target = self
      item.state = f == format ? .on : .off
      item.representedObject = f.rawValue
      formatMenu.addItem(item)
    }
    let formatItem = NSMenuItem(title: "포맷", action: nil, keyEquivalent: "")
    formatItem.submenu = formatMenu
    menu.addItem(formatItem)

    if let name = lastSourceName {
      let nameItem = NSMenuItem(title: name, action: nil, keyEquivalent: "")
      nameItem.isEnabled = false
      menu.addItem(nameItem)
    }

    let status = NSMenuItem(title: lastStatus, action: nil, keyEquivalent: "")
    status.isEnabled = false
    menu.addItem(status)

    let save = NSMenuItem(title: "저장…", action: #selector(saveLast), keyEquivalent: "")
    save.target = self
    save.isEnabled = lastFile.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    menu.addItem(save)
    menu.addItem(.separator())

    let quit = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
    quit.target = self
    menu.addItem(quit)
    statusItem.menu = menu
    statusItem.button?.appearsDisabled = !isOn
  }

  private func fail(_ message: String) {
    lastStatus = message
    lastSourceName = nil
    rebuildMenu()
    if isNotify { toast.show(message, error: true) }
  }

  @objc private func saveLast() {
    guard let src = lastFile, FileManager.default.fileExists(atPath: src.path) else {
      fail("실패: 저장할 파일이 없습니다")
      lastFile = nil
      rebuildMenu()
      return
    }

    NSApp.activate(ignoringOtherApps: true)
    let panel = NSSavePanel()
    let type = OutputFormat(rawValue: src.pathExtension.lowercased())?.utType ?? .webP
    panel.allowedContentTypes = [type]
    panel.canCreateDirectories = true
    panel.isExtensionHidden = false
    panel.nameFieldStringValue = src.lastPathComponent
    panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    guard panel.runModal() == .OK, let dest = panel.url else { return }
    if dest.standardizedFileURL == src.standardizedFileURL { return }
    do {
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: src, to: dest)
      toast.show("저장 \(dest.lastPathComponent)")
    } catch {
      fail("실패: \(error.localizedDescription)")
    }
  }

  @objc private func pickFormat(_ sender: NSMenuItem) {
    guard let raw = sender.representedObject as? String,
          let picked = OutputFormat(rawValue: raw) else { return }
    format = picked
    if lastFile == nil {
      lastStatus = "복사하면 \(picked.label)로 바꿉니다"
    }
    rebuildMenu()
  }

  @objc private func toggleOn() {
    isOn.toggle()
    if isOn {
      ignoreChange = NSPasteboard.general.changeCount
      lastChange = ignoreChange
    }
    rebuildMenu()
  }

  @objc private func toggleNotify() {
    isNotify.toggle()
    rebuildMenu()
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }
}


