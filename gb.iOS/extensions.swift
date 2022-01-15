//
//  extensions.swift
//  gb.iOS
//
//  Created by Jan on 07.01.22.
//

import Foundation

extension UInt8 {
    var hex:String {
        return String(format: "0x%02X", self)
    }
    var u16:UInt16 {
        UInt16(self)
    }
    var lowerNibble:UInt8 {
        self & 0x0f
    }
    var upperNibble:UInt8 {
        self & 0xf0
    }
}

extension Bool {
    var int16:UInt16 {
        self ? 1 : 0
    }
    var int8:UInt8 {
        self ? 1 : 0
    }
}

extension UInt16 {
    var hex:String {
        return String(format: "0x%04X", self)
    }
    var hiByte:UInt8 {
        UInt8(self >> 8)
    }
    var loByte:UInt8 {
        UInt8(self & 0b1111_1111)
    }
}

extension String {
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }

    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }

    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }

    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
}

extension Notification.Name {
    static var consoleOutput: Notification.Name {
        return .init(rawValue: "Emulator.ConsoleOutput")
    }
}

