//
//  HttpServer.swift
//  Swifter
//  Copyright (c) 2014 Damian Kołakowski. All rights reserved.
//

import Foundation

open class HttpServer
{
    public typealias Handler = (HttpRequest) -> HttpResponse
    
    var handlers: [(expression: NSRegularExpression, handler: Handler)] = []
    var clientSockets: Set<CInt> = []
    let clientSocketsLock = 0
    var acceptSocket: CInt = -1
    
    let matchingOptions = NSRegularExpression.MatchingOptions(rawValue: 0)
    let expressionOptions = NSRegularExpression.Options(rawValue: 0)
    
    public init(){
    }
    
    open subscript (path: String) -> Handler? {
        get {
            return nil
        }
        set ( newValue ) {
            do {
                let regex = try NSRegularExpression(pattern: path, options: expressionOptions)
                if let newHandler = newValue {
                    handlers.append(expression: regex, handler: newHandler)
                }
            } catch {
                    
            }
        }
    }
    
    open func routes() -> [String] { return handlers.map { $0.0.pattern } }
    
    open func start(_ listenPort: in_port_t = 8080, error: NSErrorPointer? = nil) -> Bool {
        stop()
        if let socket = Socket.tcpForListen(listenPort, error: error) {
            self.acceptSocket = socket
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).async(execute: {
                while let socket = Socket.acceptClientSocket(self.acceptSocket) {
                    HttpServer.lock(self.clientSocketsLock) {
                        self.clientSockets.insert(socket)
                    }
                    if self.acceptSocket == -1 { return }
                    let socketAddress = Socket.peername(socket)
                    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).async(execute: {
                        let parser = HttpParser()
                        while let request = parser.nextHttpRequest(socket) {
                            let keepAlive = parser.supportsKeepAlive(request.headers)
                            if let (expression, handler) = self.findHandler(request.url) {
                                let capturedUrlsGroups = self.captureExpressionGroups(expression, value: request.url)
                                let updatedRequest = HttpRequest(url: request.url, urlParams: request.urlParams, method: request.method, headers: request.headers, body: request.body, capturedUrlGroups: capturedUrlsGroups, address: socketAddress)
                                
                                HttpServer.respond(socket, response: handler(updatedRequest), keepAlive: keepAlive)
                            } else {
                                HttpServer.respond(socket, response: HttpResponse.notFound, keepAlive: keepAlive)
                            }
                            if !keepAlive { break }
                        }
                        Socket.release(socket)
                        HttpServer.lock(self.clientSocketsLock) {
                            self.clientSockets.remove(socket)
                        }
                    })
                }
                self.stop()
            })
            return true
        }
        return false
    }
    
    open func findHandler(_ url:String) -> (NSRegularExpression, Handler)? {
        return self.handlers.filter {
            $0.0.numberOfMatches(in: url, options: self.matchingOptions, range: HttpServer.asciiRange(url)) > 0
        }.first
    }
    
    open func captureExpressionGroups(_ expression: NSRegularExpression, value: String) -> [String] {
        var capturedGroups = [String]()
        if let result = expression.firstMatch(in: value, options: matchingOptions, range: HttpServer.asciiRange(value)) {
            let nsValue: NSString = value as NSString
            for i in 1  ..< result.numberOfRanges  {
                if let group = nsValue.substring(with: result.rangeAt(i)).stringByRemovingPercentEncoding {
                    capturedGroups.append(group)
                }
            }
        }
        return capturedGroups
    }
    
    open func stop() {
        Socket.release(acceptSocket)
        acceptSocket = -1
        HttpServer.lock(self.clientSocketsLock as AnyObject) {
            for clientSocket in self.clientSockets {
                Socket.release(clientSocket)
            }
            self.clientSockets.removeAll(keepingCapacity: true)
        }
    }
    
    open class func asciiRange(_ value: String) -> NSRange {
        return NSMakeRange(0, value.lengthOfBytes(using: String.Encoding.ascii))
    }
    
    open class func lock(_ handle: AnyObject, closure: () -> ()) {
        objc_sync_enter(handle)
        closure()
        objc_sync_exit(handle)
    }
    
    open class func respond(_ socket: CInt, response: HttpResponse, keepAlive: Bool) {
        Socket.writeUTF8(socket, string: "HTTP/1.1 \(response.statusCode()) \(response.reasonPhrase())\r\n")
        if let body = response.body() {
            Socket.writeASCII(socket, string: "Content-Length: \(body.count)\r\n")
        } else {
            Socket.writeASCII(socket, string: "Content-Length: 0\r\n")
        }
        if keepAlive {
            Socket.writeASCII(socket, string: "Connection: keep-alive\r\n")
        }
        for (name, value) in response.headers() {
            Socket.writeASCII(socket, string: "\(name): \(value)\r\n")
        }
        Socket.writeASCII(socket, string: "\r\n")
        if let body = response.body() {
            Socket.writeData(socket, data: body)
        }
    }
}

