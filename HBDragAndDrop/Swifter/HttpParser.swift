//
//  HttpParser.swift
//  Swifter
//  Copyright (c) 2014 Damian Kołakowski. All rights reserved.
//

import Foundation

class HttpParser {
    
    func err(_ reason: String) -> NSError {
        return NSError(domain: "HttpParser", code: 0, userInfo: [NSLocalizedDescriptionKey : reason])
    }
    
    func nextHttpRequest(_ socket: CInt, error:NSErrorPointer? = nil) -> HttpRequest? {
        if let statusLine = nextLine(socket, error: error) {
            let statusTokens = statusLine.components(separatedBy: " ")
            //print(statusTokens)
            if ( statusTokens.count < 3 ) {
                if error != nil { error??.pointee = err("Invalid status line: \(statusLine)") }
                return nil
            }
            let method = statusTokens[0]
            let path = statusTokens[1]
            let urlParams = extractUrlParams(path)
            // TODO extract query parameters
            if let headers = nextHeaders(socket, error: error!) {
                // TODO detect content-type and handle:
                // 'application/x-www-form-urlencoded' -> Dictionary
                // 'multipart' -> Dictionary
                if let contentLength = headers["content-length"], let contentLengthValue = Int(contentLength) {
                    let body = nextBody(socket, size: contentLengthValue, error: error)
                    return HttpRequest(url: path, urlParams: urlParams, method: method, headers: headers, body: body, capturedUrlGroups: [], address: nil)
                }
                return HttpRequest(url: path, urlParams: urlParams, method: method, headers: headers, body: nil, capturedUrlGroups: [], address: nil)
            }
        }
        return nil
    }
    
    fileprivate func extractUrlParams(_ url: String) -> [(String, String)] {
        if let query = url.components(separatedBy: "?").last {
            return query.components(separatedBy: "&").map { (param:String) -> (String, String) in
                let tokens = param.components(separatedBy: "=")
                if tokens.count >= 2 {
                    let key = tokens[0].stringByRemovingPercentEncoding
                    let value = tokens[1].stringByRemovingPercentEncoding
                    if key != nil && value != nil { return (key!, value!) }
                }
                return ("","")
            }
        }
        return []
    }
    
    fileprivate func nextBody(_ socket: CInt, size: Int , error:NSErrorPointer?) -> String? {
        var body = ""
        var counter = 0;
        while ( counter < size ) {
            let c = nextInt8(socket)
            if ( c < 0 ) {
                if error != nil { error??.pointee = err("IO error while reading body") }
                return nil
            }
            body.append(String(describing: UnicodeScalar(c)))
            counter += 1;
        }
        return body
    }
    
    fileprivate func nextHeaders(_ socket: CInt, error:NSErrorPointer) -> Dictionary<String, String>? {
        var headers = Dictionary<String, String>()
        while let headerLine = nextLine(socket, error: error) {
            if ( headerLine.isEmpty ) {
                return headers
            }
            let headerTokens = headerLine.components(separatedBy: ":")
            if ( headerTokens.count >= 2 ) {
                // RFC 2616 - "Hypertext Transfer Protocol -- HTTP/1.1", paragraph 4.2, "Message Headers":
                // "Each header field consists of a name followed by a colon (":") and the field value. Field names are case-insensitive."
                // We can keep lower case version.
                let headerName = headerTokens[0].lowercased()
                let headerValue = headerTokens[1].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if ( !headerName.isEmpty && !headerValue.isEmpty ) {
                    headers.updateValue(headerValue, forKey: headerName)
                }
            }
        }
        return nil
    }

    fileprivate func nextInt8(_ socket: CInt) -> Int {
        var buffer = [UInt8](repeating: 0, count: 1);
        let next = recv(socket as Int32, &buffer, Int(buffer.count), 0)
        if next <= 0 { return next }
        return Int(buffer[0])
    }
    
    fileprivate func nextLine(_ socket: CInt, error:NSErrorPointer?) -> String? {
        var characters: String = ""
        var n = 0
        repeat {
            n = nextInt8(socket)
            if ( n > 13 /* CR */ ) { characters.append(Character(UnicodeScalar(n)!)) }
        } while ( n > 0 && n != 10 /* NL */)
        if ( n == -1 && characters.isEmpty ) {
            if error != nil { error??.pointee = Socket.lastErr("recv(...) failed.") }
            return nil
        }
        return characters
    }
    
    func supportsKeepAlive(_ headers: Dictionary<String, String>) -> Bool {
        if let value = headers["connection"] {
            return "keep-alive" == value.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).lowercased()
        }
        return false
    }
}
