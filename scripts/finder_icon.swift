#!/usr/bin/env swift
import AppKit
import Darwin

struct IconError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}
struct Backup: Codable {
    let target: String
    let hadCustomIcon: Bool
}
let fm = FileManager.default
let workspace = NSWorkspace.shared

func absoluteURL(_ path: String) throws -> URL {
    guard path.hasPrefix("/") else { throw IconError("请使用绝对路径：\(path)") }
    return URL(fileURLWithPath: path).standardizedFileURL
}
func checkedTarget(_ path: String, requireWritable: Bool) throws -> URL {
    let url = try absoluteURL(path)
    let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isPackageKey])
    guard values.isSymbolicLink != true, values.isPackage != true else {
        throw IconError("不支持符号链接或包目录：\(path)")
    }
    guard fm.fileExists(atPath: url.path), !requireWritable || fm.isWritableFile(atPath: url.path) else {
        throw IconError("目标不存在或不可写：\(path)")
    }
    return url
}
func hasCustomIcon(_ url: URL) throws -> Bool {
    var bytes = [UInt8](repeating: 0, count: 32)
    let count = bytes.withUnsafeMutableBytes {
        getxattr(url.path, "com.apple.FinderInfo", $0.baseAddress, $0.count, 0, 0)
    }
    if count == -1 {
        if errno == ENOATTR { return false }
        throw IconError("无法读取 FinderInfo：\(String(cString: strerror(errno)))")
    }
    guard count >= 10 else { throw IconError("FinderInfo 数据长度异常") }
    return bytes[8] & 0x04 != 0
}
func writeNew(_ data: Data, _ url: URL) throws {
    guard !fm.fileExists(atPath: url.path) else { throw IconError("拒绝覆盖已有文件：\(url.path)") }
    try data.write(to: url, options: .withoutOverwriting)
}
func exportPNG(_ target: URL, _ output: URL) throws {
    let icon = workspace.icon(forFile: target.path)
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024,
        pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconError("无法建立透明图像画布")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    icon.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024),
        from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconError("无法编码 PNG")
    }
    try writeNew(data, output)
}
func apply(_ image: NSImage?, to target: URL, expectCustom: Bool) throws {
    guard workspace.setIcon(image, forFile: target.path, options: []) else {
        throw IconError("系统拒绝修改图标；请检查目标写入权限，备份仍保留")
    }
    guard try hasCustomIcon(target) == expectCustom else {
        throw IconError("系统调用返回成功，但图标标记验证失败；备份仍保留")
    }
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first,
          (command == "set" && args.count == 4) ||
          (["reference", "restore"].contains(command) && args.count == 3) else {
        throw IconError("用法：reference TARGET OUTPUT.png | set TARGET IMAGE NEW_BACKUP_DIR | restore TARGET BACKUP_DIR")
    }
    let target = try checkedTarget(args[1], requireWritable: command != "reference")
    switch command {
    case "reference":
        try exportPNG(target, absoluteURL(args[2]))
    case "set":
        let source = try absoluteURL(args[2])
        guard let image = NSImage(contentsOf: source), image.isValid else {
            throw IconError("无法读取图像：\(source.path)")
        }
        let directory = try absoluteURL(args[3])
        let resolvedBackup = directory.resolvingSymlinksInPath().path
        let resolvedTarget = target.resolvingSymlinksInPath().path
        guard resolvedBackup != resolvedTarget,
              !resolvedBackup.hasPrefix(resolvedTarget + "/") else {
            throw IconError("备份目录必须放在目标之外")
        }
        guard !fm.fileExists(atPath: directory.path) else {
            throw IconError("备份目录已存在，请选择新的目录")
        }
        let custom = try hasCustomIcon(target)
        let previous = custom ? workspace.icon(forFile: target.path).tiffRepresentation : nil
        if custom && previous == nil { throw IconError("无法备份原图标，取消替换") }
        try fm.createDirectory(at: directory, withIntermediateDirectories: false)
        if let data = previous { try writeNew(data, directory.appendingPathComponent("previous.tiff")) }
        let state = Backup(target: resolvedTarget, hadCustomIcon: custom)
        try writeNew(JSONEncoder().encode(state), directory.appendingPathComponent("state.json"))
        try apply(image, to: target, expectCustom: true)
        print("备份：\(directory.path)")
    case "restore":
        let directory = try absoluteURL(args[2])
        let state = try JSONDecoder().decode(Backup.self,
            from: Data(contentsOf: directory.appendingPathComponent("state.json")))
        guard state.target == target.resolvingSymlinksInPath().path else {
            throw IconError("备份对应的目标路径不匹配")
        }
        var image: NSImage? = nil
        if state.hadCustomIcon {
            image = NSImage(contentsOf: directory.appendingPathComponent("previous.tiff"))
            guard image?.isValid == true else { throw IconError("原图标备份缺失或损坏") }
        }
        try apply(image, to: target, expectCustom: state.hadCustomIcon)
    default: break
    }
    print("OK: \(command) \(target.path)")
} catch {
    fputs("错误：\(error)\n", stderr)
    exit(1)
}
