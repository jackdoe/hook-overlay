import Foundation

class SocketServer {
    let socketPath: String
    var onRequest: ((HookRequest) -> Void)?

    private var serverFD: Int32 = -1
    private var running = false

    init(path: String = "/tmp/claude-hook.sock") {
        self.socketPath = path
    }

    func start() throws {
        unlink(socketPath)

        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            throw NSError(domain: "SocketServer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "socket() failed: \(errno)"])
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            throw NSError(domain: "SocketServer", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Socket path too long"])
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dst in
                for i in 0..<pathBytes.count { dst[i] = pathBytes[i] }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sa_family_t>.size + socketPath.utf8.count + 1)
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(serverFD, $0, addrLen) }
        }
        guard bindResult == 0 else {
            close(serverFD)
            throw NSError(domain: "SocketServer", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "bind() failed: \(errno)"])
        }

        chmod(socketPath, 0o777)

        guard listen(serverFD, 20) == 0 else {
            close(serverFD)
            throw NSError(domain: "SocketServer", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "listen() failed: \(errno)"])
        }

        running = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.acceptLoop() }
        NSLog("HookOverlay: listening on %@", socketPath)
    }

    func stop() {
        running = false
        if serverFD >= 0 { close(serverFD); serverFD = -1 }
        unlink(socketPath)
    }

    func respond(to request: HookRequest, with response: HookResponse) {
        let data = response.toJSON(request: request)
        data.withUnsafeBytes { buf in
            if let ptr = buf.baseAddress { _ = write(request.clientFD, ptr, buf.count) }
        }
        _ = write(request.clientFD, "\n", 1)
        close(request.clientFD)
    }

    func reject(_ request: HookRequest) {
        respond(to: request, with: .deny)
    }

    private func acceptLoop() {
        signal(SIGPIPE, SIG_IGN)

        while running {
            let clientFD = accept(serverFD, nil, nil)
            guard clientFD >= 0 else {
                if running { usleep(10_000) }
                continue
            }

            var tv = timeval(tv_sec: 5, tv_usec: 0)
            setsockopt(clientFD, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.handleClient(clientFD) }
        }
    }

    private func handleClient(_ fd: Int32) {
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 8192)
        defer { buffer.deallocate() }

        while true {
            let n = read(fd, buffer, 8192)
            if n <= 0 { break }
            data.append(buffer, count: n)
            if data.count > 1_048_576 { break }
        }

        guard !data.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { close(fd); return }


        let request = HookRequest(
            sessionId: json["session_id"] as? String ?? "unknown",
            toolName: json["tool_name"] as? String ?? "unknown",
            toolInput: json["tool_input"] as? [String: Any] ?? [:],
            cwd: json["cwd"] as? String ?? "unknown",
            permissionSuggestions: json["permission_suggestions"] as? [[String: Any]],
            clientFD: fd
        )

        DispatchQueue.main.async { [weak self] in self?.onRequest?(request) }
    }
}
