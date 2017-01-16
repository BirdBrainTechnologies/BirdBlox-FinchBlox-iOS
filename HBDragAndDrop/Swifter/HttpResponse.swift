//
//  HttpResponse.swift
//  Swifter
//  Copyright (c) 2014 Damian Kołakowski. All rights reserved.
//

import Foundation

public enum HttpResponseBody {
    
    case json(AnyObject)
    case xml(AnyObject)
    case plist(AnyObject)
    case html(String)
    case raw(String)
    
    func data() -> String? {
        switch self {
        case .json(let object):
            if JSONSerialization.isValidJSONObject(object) {
                do {
                    let json = try JSONSerialization.data(withJSONObject: object, options: JSONSerialization.WritingOptions.prettyPrinted)
                    if let nsString = NSString(data: json, encoding: String.Encoding.utf8.rawValue) {
                        return nsString as String
                    }
                } catch let serializationError as NSError {
                    return "Serialisation error: \(serializationError)"
                }
            }
            return "Invalid object to serialise."
        case .xml(_):
            return "XML serialization not supported."
        case .plist(let object):
            let format = PropertyListSerialization.PropertyListFormat.xml
            if PropertyListSerialization.propertyList(object, isValidFor: format) {
                do {
                    let plist = try PropertyListSerialization.data(fromPropertyList: object, format: format, options: 0)
                    if let nsString = NSString(data: plist, encoding: String.Encoding.utf8.rawValue) {
                        return nsString as String
                    }
                } catch let serializationError as NSError {
                    return "Serialisation error: \(serializationError)"
                }
            }
            return "Invalid object to serialise."
        case .raw(let body):
            return body
        case .html(let body):
            return "<html><body>\(body)</body></html>"
        }
    }
}

public enum HttpResponse {
    
    case ok(HttpResponseBody), created, accepted
    case movedPermanently(String)
    case badRequest, unauthorized, forbidden, notFound
    case internalServerError
    case raw(Int, Data)
    
    func statusCode() -> Int {
        switch self {
        case .ok(_)                 : return 200
        case .created               : return 201
        case .accepted              : return 202
        case .movedPermanently      : return 301
        case .badRequest            : return 400
        case .unauthorized          : return 401
        case .forbidden             : return 403
        case .notFound              : return 404
        case .internalServerError   : return 500
        case .raw(let code, _)      : return code
        }
    }
    
    func reasonPhrase() -> String {
        switch self {
        case .ok(_)                 : return "OK"
        case .created               : return "Created"
        case .accepted              : return "Accepted"
        case .movedPermanently      : return "Moved Permanently"
        case .badRequest            : return "Bad Request"
        case .unauthorized          : return "Unauthorized"
        case .forbidden             : return "Forbidden"
        case .notFound              : return "Not Found"
        case .internalServerError   : return "Internal Server Error"
        case .raw(_,_)              : return "Custom"
        }
    }
    
    func headers() -> [String: String] {
        var headers = [String:String]()
        headers["Server"] = "Swifter"
        headers["Access-Control-Allow-Origin"] = "*"
        switch self {
        case .movedPermanently(let location) : headers["Location"] = location
        default:[]
        }
        return headers
    }
    
    func body() -> Data? {
        switch self {
        case .ok(let body)      : return body.data()?.data(using: String.Encoding.utf8, allowLossyConversion: false)
        case .raw(_, let data)  : return data
        default                 : return nil
        }
    }
}
