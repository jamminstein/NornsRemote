import Foundation

/// Builds raw OSC 1.0 packets for sending over UDP.
struct OSCMessage {
    let address: String
    let arguments: [OSCArgument]

    enum OSCArgument {
        case int32(Int32)
        case float32(Float)
        case string(String)
    }

    /// Encode this message into an OSC-compliant Data blob.
    func encode() -> Data {
        var data = Data()

        // Address pattern (null-terminated, padded to 4-byte boundary)
        data.append(oscString(address))

        // Type tag string
        var typeTag = ","
        for arg in arguments {
            switch arg {
            case .int32: typeTag += "i"
            case .float32: typeTag += "f"
            case .string: typeTag += "s"
            }
        }
        data.append(oscString(typeTag))

        // Arguments
        for arg in arguments {
            switch arg {
            case .int32(let v):
                var big = v.bigEndian
                data.append(Data(bytes: &big, count: 4))
            case .float32(let v):
                var bits = v.bitPattern.bigEndian
                data.append(Data(bytes: &bits, count: 4))
            case .string(let v):
                data.append(oscString(v))
            }
        }

        return data
    }

    /// OSC string: null-terminated, padded to 4-byte boundary.
    private func oscString(_ s: String) -> Data {
        var d = s.data(using: .utf8) ?? Data()
        d.append(0) // null terminator
        while d.count % 4 != 0 {
            d.append(0) // pad
        }
        return d
    }
}
