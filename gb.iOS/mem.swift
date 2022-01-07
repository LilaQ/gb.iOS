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

    private var memory: [UInt8] = [UInt8](repeating: 0, count: 0x10000)
    private var BOOTROM_ENABLED = true
    public var PC : UInt16 = 0x0000
    public var SP : UInt16 = 0x0000

    @discardableResult
    func getByte(addr: UInt16)->UInt8 {
        //  check for special addresses
        
        //  increasing PC by 1 on getByte
        self.PC += 1
        
        //  ... else return just byte at mem
        if BOOTROM_ENABLED && addr <= 0x100 {
            return BOOTROM[Int(addr)]
        }
        return memory[Int(addr)]
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
    
    func setByte(addr: UInt16, val: UInt8) {
        memory[Int(addr)] = val
    }
    
    @discardableResult
    func getHalfWord(addr: UInt16)->UInt16 {
        let lo = getByte(addr: addr)
        let hi = getByte(addr: addr+1)
        return UInt16(hi) * 0x100 + UInt16(lo)
    }
    
    init() {
        print("MEMORY INIT")
    }
}
