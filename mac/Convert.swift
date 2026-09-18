import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ConvertError: LocalizedError {
  case noImage
  case noCGImage
  case encodeFailed
  case writeFailed

  var errorDescription: String? {
    switch self {
    case .noImage: return "이미지가 없습니다"
    case .noCGImage: return "이미지를 읽지 못했습니다"
    case .encodeFailed: return "인코딩 실패"
    case .writeFailed: return "파일을 쓰지 못했습니다"
    }
  }
}

enum OutputFormat: String, CaseIterable {
  case webp
  case avif

  static let defaultsKey = "webp-paste.format"

  var ext: String { rawValue }

  var label: String {
    switch self {
    case .webp: return "WebP"
    case .avif: return "AVIF"
    }
  }

  var utType: UTType {
    switch self {
    case .webp: return .webP
    case .avif: return UTType(filenameExtension: "avif") ?? UTType("public.avif") ?? .webP
    }
  }

  var uti: CFString {
    switch self {
    case .webp: return "org.webmproject.webp" as CFString
    case .avif: return "public.avif" as CFString
    }
  }

  static func stored() -> OutputFormat {
    OutputFormat(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .webp
  }
}

enum ClipboardAction {
  case skip(String)
  case convertFile(URL)
  case convertPasteboard
}

enum Converter {
  static let quality: Float = 82
  static let maxEdge: Int = 2560
  static let keepTemps = 12

  static func cacheDir() throws -> URL {
    let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let dir = base.appendingPathComponent("webp-paste", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  static func bytes(_ n: Int) -> String {
    if n < 1024 { return "\(n) B" }
    if n < 1024 * 1024 {
      return String(format: "%.1f KB", Double(n) / 1024)
    }
    return String(format: "%.2f MB", Double(n) / (1024 * 1024))
  }

  static func fileURLs(from pb: NSPasteboard) -> [URL] {
    if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
      let files = urls.filter(\.isFileURL)
      if !files.isEmpty { return files }
    }
    let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    if let paths = pb.propertyList(forType: filenamesType) as? [String] {
      return paths.map { URL(fileURLWithPath: $0) }
    }
    if let raw = pb.string(forType: .fileURL) {
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if let url = URL(string: trimmed), url.isFileURL { return [url] }
      if trimmed.hasPrefix("/") { return [URL(fileURLWithPath: trimmed)] }
    }
    return []
  }

  static func action(for pb: NSPasteboard, cacheDir: URL, format: OutputFormat) -> ClipboardAction {
    let types = Set((pb.types ?? []).map(\.rawValue))
    if types.contains("com.adobe.pdf") || types.contains(NSPasteboard.PasteboardType.pdf.rawValue) {
      return .skip("pdf")
    }
    if types.contains("com.compuserve.gif") {
      return .skip("gif")
    }

    let urls = fileURLs(from: pb)
    if urls.count > 1 { return .skip("multiple-files") }
    if let url = urls.first {
      let ext = url.pathExtension.lowercased()
      if ext == "gif" { return .skip("gif") }
      if ext == "pdf" { return .skip("pdf") }
      if isOurOutput(url, cacheDir: cacheDir, format: format) { return .skip("our-\(format.ext)") }
      if ext == format.ext { return .skip("already-\(format.ext)") }
      if isImageExtension(ext) { return .convertFile(url) }
    }

    if hasRasterType(types) { return .convertPasteboard }
    if NSImage(pasteboard: pb) != nil { return .convertPasteboard }
    return .skip("not-image")
  }

  static func originalByteCount(pb: NSPasteboard, file: URL?) -> Int {
    if let file,
       let n = try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int {
      return n
    }
    if let d = pb.data(forType: .png) { return d.count }
    if let d = pb.data(forType: .tiff) { return d.count }
    if let d = pb.data(forType: NSPasteboard.PasteboardType("public.jpeg")) { return d.count }
    return 0
  }

  static func encode(file: URL, format: OutputFormat) throws -> Data {
    try encode(cg: try cgImage(fromFile: file), format: format)
  }

  static func encode(cg src: CGImage, format: OutputFormat) throws -> Data {
    let (w, h) = scaledSize(width: src.width, height: src.height)
    let stride = w * 4
    let count = h * stride
    let raw = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
    raw.initialize(repeating: 0, count: count)
    defer { raw.deallocate() }

    guard let ctx = CGContext(
      data: raw,
      width: w,
      height: h,
      bitsPerComponent: 8,
      bytesPerRow: stride,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw ConvertError.noCGImage }
    ctx.interpolationQuality = .high
    ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))

    switch format {
    case .webp:
      unpremultiplyRGBA(raw, pixelCount: w * h)
      var outPtr: UnsafeMutablePointer<UInt8>?
      var outLen: Int = 0
      let ok = webp_encode_rgba(raw, Int32(w), Int32(h), Int32(stride), quality, &outPtr, &outLen)
      defer {
        if let outPtr { webp_free(outPtr) }
      }
      guard ok == 0, let outPtr, outLen > 0 else { throw ConvertError.encodeFailed }
      return Data(bytes: outPtr, count: outLen)
    case .avif:
      guard let scaled = ctx.makeImage() else { throw ConvertError.noCGImage }
      return try encodeImageIO(scaled, uti: format.uti)
    }
  }

  static func writeTemp(_ data: Data, format: OutputFormat) throws -> URL {
    let dir = try cacheDir()
    let stamp = ISO8601DateFormatter.string(
      from: Date(),
      timeZone: .current,
      formatOptions: [.withInternetDateTime]
    )
    .replacingOccurrences(of: ":", with: "-")
    let url = dir.appendingPathComponent("slim-\(stamp).\(format.ext)")
    do {
      try data.write(to: url, options: .atomic)
    } catch {
      throw ConvertError.writeFailed
    }
    prune(dir)
    return url
  }

  static func putFileOnPasteboard(_ url: URL, pb: NSPasteboard = .general) {
    pb.clearContents()
    pb.writeObjects([url as NSURL])
    pb.setPropertyList([url.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
  }

  static func loadCGImage(file: URL?, pb: NSPasteboard) throws -> CGImage {
    if let file { return try cgImage(fromFile: file) }
    return try cgImage(fromPasteboard: pb)
  }

  private static func cgImage(fromFile url: URL) throws -> CGImage {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          CGImageSourceGetCount(src) > 0,
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
      throw ConvertError.noCGImage
    }
    return img
  }

  private static func cgImage(fromPasteboard pb: NSPasteboard) throws -> CGImage {
    let candidates: [NSPasteboard.PasteboardType] = [
      .png,
      .tiff,
      NSPasteboard.PasteboardType("public.jpeg"),
      NSPasteboard.PasteboardType("public.heic"),
    ]
    for type in candidates {
      if let data = pb.data(forType: type),
         let src = CGImageSourceCreateWithData(data as CFData, nil),
         let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
        return img
      }
    }
    if let img = NSImage(pasteboard: pb),
       let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let cg = rep.cgImage {
      return cg
    }
    throw ConvertError.noCGImage
  }

  // WebPEncodeRGBA wants straight alpha. CGContext only draws premultiplied.
  private static func unpremultiplyRGBA(_ p: UnsafeMutablePointer<UInt8>, pixelCount: Int) {
    var i = 0
    while i < pixelCount {
      let a = Int(p[i * 4 + 3])
      if a != 0 && a != 255 {
        p[i * 4] = UInt8(min(255, Int(p[i * 4]) * 255 / a))
        p[i * 4 + 1] = UInt8(min(255, Int(p[i * 4 + 1]) * 255 / a))
        p[i * 4 + 2] = UInt8(min(255, Int(p[i * 4 + 2]) * 255 / a))
      }
      i += 1
    }
  }

  private static func scaledSize(width: Int, height: Int) -> (Int, Int) {
    let edge = max(width, height)
    guard edge > maxEdge else { return (width, height) }
    let scale = CGFloat(maxEdge) / CGFloat(edge)
    return (
      max(1, Int((CGFloat(width) * scale).rounded())),
      max(1, Int((CGFloat(height) * scale).rounded()))
    )
  }

  private static func encodeImageIO(_ img: CGImage, uti: CFString) throws -> Data {
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, uti, 1, nil) else {
      throw ConvertError.encodeFailed
    }
    let props: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: Double(quality) / 100
    ]
    CGImageDestinationAddImage(dest, img, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { throw ConvertError.encodeFailed }
    return data as Data
  }

  private static func isImageExtension(_ ext: String) -> Bool {
    ["png", "jpg", "jpeg", "tif", "tiff", "heic", "heif", "bmp", "gif", "webp", "avif"].contains(ext)
  }

  private static func isOurOutput(_ url: URL, cacheDir: URL, format: OutputFormat) -> Bool {
    url.pathExtension.lowercased() == format.ext
      && url.standardizedFileURL.path.hasPrefix(cacheDir.standardizedFileURL.path)
  }

  private static func hasRasterType(_ types: Set<String>) -> Bool {
    let raster: Set<String> = [
      NSPasteboard.PasteboardType.png.rawValue,
      NSPasteboard.PasteboardType.tiff.rawValue,
      "public.jpeg",
      "public.heic",
      "public.bmp",
      "com.microsoft.bmp",
    ]
    return !types.isDisjoint(with: raster)
  }

  private static func prune(_ dir: URL) {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(
      at: dir,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: .skipsHiddenFiles
    ) else { return }
    let webps = files.filter {
      let ext = $0.pathExtension.lowercased()
      return ext == "webp" || ext == "avif"
    }
      .sorted { a, b in
        let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return da > db
      }
    for extra in webps.dropFirst(keepTemps) {
      try? fm.removeItem(at: extra)
    }
  }
}

func convertCLI(input: String, output: String) {
  let inURL = URL(fileURLWithPath: input)
  let outURL = URL(fileURLWithPath: output)
  let format = OutputFormat(rawValue: outURL.pathExtension.lowercased()) ?? .webp
  do {
    let data = try Converter.encode(file: inURL, format: format)
    try data.write(to: outURL, options: .atomic)
    let orig = (try? FileManager.default.attributesOfItem(atPath: inURL.path)[.size] as? Int) ?? 0
    print("\(Converter.bytes(orig)) → \(Converter.bytes(data.count)) \(format.label)")
  } catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
  }
}

func convertOnce() {
  _ = NSApplication.shared
  let pb = NSPasteboard.general
  let cache: URL
  do {
    cache = try Converter.cacheDir()
  } catch {
    fputs("캐시 폴더를 만들지 못했습니다\n", stderr)
    exit(1)
  }
  let format = OutputFormat.stored()
  let file: URL?
  switch Converter.action(for: pb, cacheDir: cache, format: format) {
  case .skip(let reason):
    fputs("건너뜀: \(reason)\n", stderr)
    exit(2)
  case .convertFile(let url):
    file = url
  case .convertPasteboard:
    file = nil
  }
  do {
    let image = try Converter.loadCGImage(file: file, pb: pb)
    let orig = Converter.originalByteCount(pb: pb, file: file)
    let data = try Converter.encode(cg: image, format: format)
    let out = try Converter.writeTemp(data, format: format)
    Converter.putFileOnPasteboard(out)
    print("\(Converter.bytes(orig)) → \(Converter.bytes(data.count)) \(format.label) \(out.path)")
  } catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
  }
}
