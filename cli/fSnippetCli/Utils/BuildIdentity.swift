import Foundation
import MachO

/// Identity of the running binary, exposed over REST so callers can tell which build is live (Issue253).
///
/// - `executableUUID()`: LC_UUID of the main image loaded in memory. Set by the linker per link,
///   so it identifies the exact binary (compare with `dwarfdump --uuid <binary>`).
/// - `executableModificationTime()`: mtime of the main executable file in UTC ISO8601 — the same
///   "build time" notion used by prj15 `verify-running-build.sh` (`stat -f %Sm`).
enum BuildIdentity {
  static func executableUUID() -> String? {
    guard let header = _dyld_get_image_header(0) else { return nil }
    guard header.pointee.magic == MH_MAGIC_64 else { return nil }
    var cursor = UnsafeRawPointer(header).advanced(by: MemoryLayout<mach_header_64>.size)
    for _ in 0..<header.pointee.ncmds {
      let cmd = cursor.assumingMemoryBound(to: load_command.self).pointee
      if cmd.cmd == UInt32(LC_UUID) {
        let u = cursor.assumingMemoryBound(to: uuid_command.self).pointee.uuid
        return UUID(uuid: u).uuidString
      }
      cursor = cursor.advanced(by: Int(cmd.cmdsize))
    }
    return nil
  }

  static func executableModificationTime() -> String? {
    guard let path = Bundle.main.executablePath,
          let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    else { return nil }
    let f = ISO8601DateFormatter()
    f.timeZone = TimeZone(identifier: "UTC")
    return f.string(from: date)
  }
}
