import Foundation
import ArArchiveKit
import SWCompression
for path in CommandLine.arguments.dropFirst() {
 let raw = try Data(contentsOf:URL(fileURLWithPath:path))
 let ar = try ArArchiveReader(archive:[UInt8](raw))
 var payload:Data? = nil
 for (header, data) in ar { if header.name == "data.tar.gz" { payload = try GzipArchive.unarchive(archive:Data(data)); break } }
 guard let tar = payload else { fatalError("No supported compressed data archive: \(path)") }
 let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
 try tar.write(to:temp); let handle = try FileHandle(forReadingFrom:temp)
 var reader = TarReader(fileHandle:handle)
 var libraries=0, bundleRoots=0, resources=0
 var bundles=Set<String>()
 while let entry = try reader.read() {
  if entry.info.type == .regular && entry.info.name.hasSuffix(".dylib") { precondition(entry.data?.isEmpty == false); libraries += 1 }
  else if entry.info.type == .directory && entry.info.name.hasSuffix(".bundle") { bundles.insert(entry.info.name); bundleRoots += 1 }
  else { for bundle in bundles where entry.info.name.hasPrefix(bundle + "/") { if entry.info.type == .regular { resources += 1 } } }
 }
 try handle.close(); try FileManager.default.removeItem(at:temp)
 precondition(libraries > 0, "No dylib found")
 precondition(bundleRoots > 0 && resources > 0, "Bundle resources not recognized")
 print("PASS \(URL(fileURLWithPath:path).lastPathComponent): dylibs=\(libraries) bundles=\(bundleRoots) bundleFiles=\(resources)")
}
