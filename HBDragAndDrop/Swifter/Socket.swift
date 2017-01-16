//
//  Socket.swift
//  Swifter
//  Copyright (c) 2014 Damian Kołakowski. All rights reserved.
//

import Foundation

/* Low level routines for POSIX sockets */

struct Socket {
        
    static func lastErr(_ reason: String) -> NSError {
        let errorCode = errno
        if let errorText = String(validatingUTF8: UnsafePointer(strerror(errorCode))) {
            return NSError(domain: "SOCKET", code: Int(errorCode), userInfo: [NSLocalizedFailureReasonErrorKey : reason, NSLocalizedDescriptionKey : errorText])
        }
        return NSError(domain: "SOCKET", code: Int(errorCode), userInfo: nil)
    }
    
    static func tcpForListen(_ port: in_port_t = 8080, error: NSErrorPointer? = nil) -> CInt? {
        let s = socket(AF_INET, SOCK_STREAM, 0)
        if ( s == -1 ) {
            if error != nil { error??.pointee = lastErr("socket(...) failed.") }
            return nil
        }
        var value: Int32 = 1;
        if ( setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size)) == -1 ) {
            release(s)
            if error != nil { error??.pointee = lastErr("setsockopt(...) failed.") }
            return nil
        }
        nosigpipe(s)
        var addr = sockaddr_in(sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size), sin_family: sa_family_t(AF_INET),
            sin_port: port_htons(port), sin_addr: in_addr(s_addr: inet_addr("0.0.0.0")), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        
        var sock_addr = sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        memcpy(&sock_addr, &addr, Int(MemoryLayout<sockaddr_in>.size))
        if ( bind(s, &sock_addr, socklen_t(MemoryLayout<sockaddr_in>.size)) == -1 ) {
            release(s)
            if error != nil { error??.pointee = lastErr("bind(...) failed.") }
            return nil
        }
        if ( listen(s, 20 /* max pending connection */ ) == -1 ) {
            release(s)
            if error != nil { error??.pointee = lastErr("listen(...) failed.") }
            return nil
        }
        return s
    }
    
    static func writeUTF8(_ socket: CInt, string: String, error: NSErrorPointer? = nil) -> Bool {
        if let nsdata = string.data(using: String.Encoding.utf8) {
            return writeData(socket, data: nsdata, error: error)
        }
        return true
    }
    
    static func writeASCII(_ socket: CInt, string: String, error: NSErrorPointer? = nil) -> Bool {
        if let nsdata = string.data(using: String.Encoding.ascii) {
            return writeData(socket, data: nsdata, error: error)
        }
        return true
    }
    
    static func writeData(_ socket: CInt, data: Data, error: NSErrorPointer? = nil) -> Bool {
        var sent = 0
        let unsafePointer = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)
        while ( sent < data.count ) {
            let s = write(socket, unsafePointer + sent, Int(data.count - sent))
            if ( s <= 0 ) {
                if error != nil { error??.pointee = lastErr("write(...) failed.") }
                return false
            }
            sent += s
        }
        return true
    }
    
    static func acceptClientSocket(_ socket: CInt, error:NSErrorPointer? = nil) -> CInt? {
        var addr = sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)), len: socklen_t = 0
        let clientSocket = accept(socket, &addr, &len)
        if ( clientSocket != -1 ) {
            Socket.nosigpipe(clientSocket)
            return clientSocket
        }
        if error != nil { error??.pointee = lastErr("accept(...) failed.") }
        return nil
    }
    
    static func nosigpipe(_ socket: CInt) {
        // prevents crashes when blocking calls are pending and the app is paused ( via Home button )
        var no_sig_pipe: Int32 = 1;
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &no_sig_pipe, socklen_t(MemoryLayout<Int32>.size));
    }
    
    static func port_htons(_ port: in_port_t) -> in_port_t {
        let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
        return isLittleEndian ? _OSSwapInt16(port) : port
    }
    
    static func release(_ socket: CInt) {
        shutdown(socket, SHUT_RDWR)
        close(socket)
    }
    
    static func peername(_ socket: CInt, error: NSErrorPointer? = nil) -> String? {
        var addr = sockaddr(), len: socklen_t = socklen_t(MemoryLayout<sockaddr>.size)
        if getpeername(socket, &addr, &len) != 0 {
            if error != nil { error??.pointee = lastErr("getpeername(...) failed.") }
            return nil
        }
        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(&addr, len, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) != 0 {
            if error != nil { error??.pointee = lastErr("getnameinfo(...) failed.") }
            return nil
        }
        return String(cString: hostBuffer)
    }
}
