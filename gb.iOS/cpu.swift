//
//  cpu.swift
//  gb.iOS
//
//  Created by Jan on 06.01.22.
//

import Darwin
import CoreFoundation

//      GAMEBOY
//  Main RAM: 8K Byte
//  Video RAM: 8K Byte
//  Resolution: 160x144 (20x18 tiles)
//  Max # of Sprites: 40
//  Max # of Sprites/line: 10
//  Clock speed: 4.194304 MHz

class REGS {
    public var A,B,C,D,E,F,H,L : UInt8
    public var BC : UInt16 {
        get {
            return UInt16(B) * 0x100 + UInt16(C)
        }
        set(v) {
            B = UInt8(v >> 8)
            C = UInt8(v & 0b1111_1111)
        }
    }
    public var DE : UInt16 {
        get {
            return UInt16(D) * 0x100 + UInt16(E)
        }
        set(v) {
            D = UInt8(v >> 8)
            E = UInt8(v & 0b1111_1111)
        }
    }
    public var HL : UInt16 {
        get {
            return UInt16(H) * 0x100 + UInt16(L)
        }
        set(v) {
            H = UInt8(v >> 8)
            L = UInt8(v & 0b1111_1111)
        }
    }
    init() {
        print("setting up REGS")
        A=0
        B=0
        C=0
        D=0
        E=0
        F=0
        H=0
        L=0
    }
}

class FLAGS {
    public var Z,N,H,C,HALT : Bool
    init() {
        print("setting up FLAGS")
        Z=false
        N=false
        H=false
        C=false
        HALT=false
    }
}

class CPU {

    private var OPCODE : UInt8 = 0x00
    private var mem : MEMORY
    private var flags : FLAGS
    private var regs : REGS
    private var cnt: Int = 0
    
    init(mem: MEMORY) {
        print("setting up CPU")
        self.mem = mem
        self.flags = FLAGS()
        self.regs = REGS()
    }

    func step() {
        //  check OPCODE
        print("\(mem.PC.hex) ", terminator: "")
        OPCODE = mem.getByte()
        switch OPCODE {
        case 0x00:
            nop()
        case 0x0c:
            inc(&regs.C, "C")
        case 0x0e:
            ld_imm(tar: &regs.C, "C")
        case 0x11:
            ld_imm(tar: &regs.DE, "HL")
        case 0x1a:
            ld_mem(tar: &regs.A, addr: regs.DE)
        case 0x20:
            jr(condition: !flags.Z, offset: mem.getSignedByte())
        case 0x21:
            ld_imm(tar: &regs.HL, "HL")
        case 0x31:
            ld_imm(tar: &mem.SP, "SP")
        case 0x32:
            ld_mem(addr: regs.HL, val: regs.A, "A")
            regs.HL -= 1
        case 0x3e:
            ld_imm(tar: &regs.A, "A")
        case 0x77:
            ld_mem(addr: regs.HL, val: regs.A, "A")
        case 0xaf:
            xor(regs.A, regs.A)
        case 0xcb:
            let CB = mem.getByte()
            switch CB {
            case 0x7c:
                bit(UInt8(regs.HL >> 8), 7, "H")
            default:
                print("Unsupported CB Opcode \(CB.hex) at location \(mem.PC.hex)")
                print("Follow up bytes: \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) ")
            }
        case 0xe0:
            ld_mem(addr: 0xFF00 + UInt16(mem.getByte()), val: regs.A, "A")
        case 0xe2:
            ld_mem(addr: 0xFF00 + UInt16(regs.C), val: regs.A, "A")
        default:
            print("Unsupported Opcode \(OPCODE.hex) at location \(mem.PC.hex)")
            print("Follow up bytes: \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) ")
            exit(1)
        }
    }
    
    func nop()->UInt16 {
        print("NOP")
        mem.getByte()
        return 1
    }
    
    func ld_mem(tar: inout UInt8, addr: UInt16)->UInt16 {
        tar = mem.getByte(addr: addr)
        return 1
    }
    
    func ld_mem(addr: UInt16, val: UInt8, _ desc: String)->UInt16 {
        mem.setByte(addr: addr, val: val)
        print("LD (\(addr)), \(desc) (\(val))")
        return 1
    }
    
    //  ld immediate - BYTE
    func ld_imm(tar: inout UInt8, _ desc: String)->UInt16 {
        tar = mem.getByte()
        print("LD \(desc), u8 (\(tar.hex))")
        return 2
    }
    
    //  ld immediate - WORD
    func ld_imm(tar: inout UInt16, _ desc: String)->UInt16 {
        let lo = mem.getByte()
        let hi = mem.getByte()
        tar = UInt16(hi) * 0x100 + UInt16(lo)
        print("LD \(desc), u16 (\(tar.hex))")
        return 3
    }
    
    func inc(_ a: inout UInt8, _ desc: String)->UInt16 {
        flags.H = (a & 0b1111) == 0b1111
        flags.C = (a & 0b1111_1111) == 0b1111_1111
        a += 1
        flags.N = false
        print("INC \(desc)")
        return 1
    }
    
    func xor(_ a: UInt8, _ b: UInt8)->UInt16 {
        flags.Z = (a^b) == 0
        print("XOR, (\(a)) (\(b)) - (Z: \(flags.Z))")
        return 1
    }
    
    func bit(_ a: UInt8, _ bit: Int, _ desc: String)->UInt16 {
        flags.Z = (a & (1<<bit)) == 0
        flags.N = false
        flags.H = true
        print("BIT \(bit), \(desc)")
        return 1
    }
    
    func jr(condition: Bool, offset: Int8)->UInt16 {
        if condition {
            mem.PC = UInt16(Int16(mem.PC) + Int16(offset))
        }
        print("JR, (\(offset))")
        return 8    //  Todo could be more
    }
    
}
