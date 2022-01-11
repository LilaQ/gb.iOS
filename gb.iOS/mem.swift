//
//  mem.swift
//  gb.iOS
//
//  Created by Jan on 06.01.22.
//

//      GAMEBOY
//  Main RAM: 8K Byte
//  Video RAM: 8K Byte
//  Resolution: 160x144 (20x18 tiles)
//  Max # of Sprites: 40
//  Max # of Sprites/line: 10
//  Clock speed: 4.194304 MHz

import SwiftUI

class MEMORY {
    
    var BOOTROM : [UInt8] = {
        print("Initializing BOOTROM..")
        let ROM = "31feffaf21ff9f32cb7c20fb2126ff0e113e8032e20c3ef3e2323e77773efce0471104012110801acd9500cd9600137bfe3420f311d80006081a1322230520f93e19ea1099212f990e0c3d2808320d20f92e0f18f3673e6457e0423e91e040041e020e0cf044fe9020fa0d20f71d20f20e13247c1e83fe6228061ec1fe6420067be20c3e87e2f04290e0421520d205204f162018cb4f0604c5cb1117c1cb11170520f522232223c9ceed6666cc0d000b03730083000c000d0008111f8889000edccc6ee6ddddd999bbbb67636e0eecccdddc999fbbb9333e3c42b9a5b9a5423c21040111a8001a13be20fe237dfe3420f506197886230520fb8620fe3e01e050"
        var arr = [UInt8](repeating: 0, count: 256)
        for i in 0..<256 {
            arr[i] = UInt8(ROM.substring(with: i*2..<i*2+2), radix: 16) ?? 0
        }
        return arr
    }()

    public var memory: [UInt8] = [UInt8](repeating: 0, count: 0x10000)
    private var BOOTROM_ENABLED = true
    public var PC : UInt16 = 0x0000
    public var SP : UInt16 = 0x0000

    @discardableResult
    func getByte(addr: UInt16)->UInt8 {
        //  check for special addresses
        
        //  increasing PC by 1 on getByte
        self.PC += 1
        
        //  ... else return just byte at mem
        return read(addr: addr)
    }
    
    func read(addr: UInt16)->UInt8 {
        if BOOTROM_ENABLED && addr < 0x100 {
            return BOOTROM[Int(addr)]
        }
        return memory[Int(addr)]
    }
    
    func write(addr: UInt16, val: UInt8) {
        switch addr {
        case 0xFF02:    //  serial output; Blarggs tests console output
            print(Character(UnicodeScalar(memory[0xFF01])), terminator: "")
            memory[0xFF02] = 0
        case 0xFF50:    //  write to disable Bootrom
            print("Disabling BOOTROM")
            BOOTROM_ENABLED = false
        default:
            memory[Int(addr)] = val
        }
        
    }
    
    func getByte()->UInt8 {
        getByte(addr: PC)
    }
    
    func getSignedByte(addr: UInt16)->Int8 {
        let v = getByte(addr: addr)
        return Int8(bitPattern: v)
    }
    
    func getSignedByte()->Int8 {
        getSignedByte(addr: PC)
    }
    
    @discardableResult
    func getHalfWord(addr: UInt16)->UInt16 {
        let lo = getByte(addr: addr)
        let hi = getByte(addr: addr+1)
        return UInt16(hi) * 0x100 + UInt16(lo)
    }
    
    func getHalfWord()->UInt16 {
        getHalfWord(addr: PC)
    }
    
    init() {
        print("MEMORY init")
        
        print("DEBUG: Fixed value of 0x90 to 0xFF44 for expected VBLANK")
        memory[0xff44]=0x90
        
        print("loading ROM...")
//        let rom = loadRom(forResource: "tetris", withExtension: "gb") ?? []
        let rom = loadRom(forResource: "instr_timing", withExtension: "gb") ?? []
//        let rom = loadRom(forResource: "04-op r,imm", withExtension: "gb") ?? []
//        let rom = loadRom(forResource: "05-op rp", withExtension: "gb") ?? []
//        let rom = loadRom(forResource: "06-ld r,r", withExtension: "gb") ?? []
//        let rom = loadRom(forResource: "07-jr,jp,call,ret,rst", withExtension: "gb") ?? []
//        let rom = loadRom(forResource: "08-misc instrs", withExtension: "gb") ?? []
        for i in 0..<rom.count {
            memory[i]=rom[i]
        }
        
    }
    
    func loadRom(forResource resource: String, withExtension fileExt: String?) -> [UInt8]? {
        // See if the file exists.
        guard let fileUrl: URL = Bundle.main.url(forResource: resource, withExtension: fileExt) else {
            print("...ROM not found - Exiting")
            exit(1)
        }

        do {
            // Get the raw data from the file.
            let rawData: Data = try Data(contentsOf: fileUrl)
            
            let u8res: [UInt8] = [UInt8](rawData)
            print("Title    : ", terminator: "")
            for i in 0x134..<0x144 {
                print(Character(UnicodeScalar(u8res[i])), terminator: "")
            }
            print()
            print("Cartridge: ", terminator: "")
            var c = ""
            switch u8res[0x147] {
            case 0x00: c = "ROM ONLY"
            case 0x01: c = "MBC1"
            case 0x02: c = "MBC1+RAM"
            case 0x03: c = "MBC1+RAM+BATTERY"
            case 0x05: c = "MBC2"
            case 0x06: c = "MBC2+BATTERY"
            default: c = "UNCLASSIFIED"
            }
            print(c)
            print("ROM Size : ", terminator: "")
            c = ""
            switch u8res[0x148] {
            case 0x00: c = "32 KB (no banking)"
            case 0x01: c = "64 KB (4 banks)"
            case 0x02: c = "128 KB (8 banks)"
            default: c = "UNCLASSIFIED"
            }
            print(c)
            print("RAM Size : ", terminator: "")
            c = ""
            switch u8res[0x148] {
            case 0x00: c = "None"
            case 0x01: c = "2 KB"
            case 0x02: c = "8 KB"
            default: c = "UNCLASSIFIED"
            }
            print(c)

            // Return the raw data as an array of bytes.
            return u8res
        } catch {
            // Couldn't read the file.
            return nil
        }
    }
}
