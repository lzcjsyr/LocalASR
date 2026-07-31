import Darwin
import Foundation

enum LocalPortAllocator {
    static func allocateLoopbackPort() throws -> UInt16 {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            throw AppError.engineFailed("无法申请本地端口。")
        }
        defer { close(socketDescriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0)
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(
                    socketDescriptor,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard bindResult == 0 else {
            throw AppError.engineFailed("无法申请本地端口。")
        }

        var allocatedAddress = sockaddr_in()
        var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &allocatedAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                getsockname(socketDescriptor, socketAddress, &addressLength)
            }
        }
        guard nameResult == 0 else {
            throw AppError.engineFailed("无法读取本地端口。")
        }

        let port = UInt16(bigEndian: allocatedAddress.sin_port)
        guard port > 0 else {
            throw AppError.engineFailed("系统返回了无效的本地端口。")
        }
        return port
    }
}
