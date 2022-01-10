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

    public var flags : FLAGS
    public var A,B,C,D,E,H,L : UInt8
    public var F: UInt8 {
        get {
            UInt8(flags.Z ? 0b1000_0000 : 0) +
            UInt8(flags.N ? 0b0100_0000 : 0) +
            UInt8(flags.H ? 0b0010_0000 : 0) +
            UInt8(flags.C ? 0b0001_0000 : 0)
        }
        set(v) {
            flags.Z = (v & 0b1000_0000) > 0
            flags.N = (v & 0b0100_0000) > 0
            flags.H = (v & 0b0010_0000) > 0
            flags.C = (v & 0b0001_0000) > 0
        }
    }
    public var AF : UInt16 {
        get {
            return (UInt16(A) << 8) | UInt16(F)
        }
        set(v) {
            A = UInt8(v >> 8)
            F = UInt8(v & 0b1111_1111)
        }
    }
    public var BC : UInt16 {
        get {
            return (UInt16(B) << 8) | UInt16(C)
        }
        set(v) {
            B = UInt8(v >> 8)
            C = UInt8(v & 0b1111_1111)
        }
    }
    public var DE : UInt16 {
        get {
            return (UInt16(D) << 8) | UInt16(E)
        }
        set(v) {
            D = UInt8(v >> 8)
            E = UInt8(v & 0b1111_1111)
        }
    }
    public var HL : UInt16 {
        get {
            return (UInt16(H) << 8) | UInt16(L)
        }
        set(v) {
            H = UInt8(v >> 8)
            L = UInt8(v & 0b1111_1111)
        }
    }
    init() {
        debugLog("setting up REGS")
        A=0
        B=0
        C=0
        D=0
        E=0
        H=0
        L=0
        self.flags = FLAGS()
    }
}

class FLAGS {
    public var Z,N,H,C,HALT : Bool
    init() {
        debugLog("setting up FLAGS")
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
    private var regs : REGS
    public var interrupts_enabled : Bool = false
    
    init(mem: MEMORY) {
        debugLog("setting up CPU")
        self.mem = mem
        self.regs = REGS()
    }

    func step() {
        //  check OPCODE
        debugLog("\(mem.PC.hex) [SP: \(mem.SP.hex)][HL: \(regs.HL.hex)][\(regs.flags.Z ? "Z":"-")\(regs.flags.N ? "N":"-")\(regs.flags.H ? "H":"-")\(regs.flags.C ? "C":"-")][A: \(regs.A.hex) B: \(regs.B.hex)] - ", terminator: "")
        if mem.PC == 0xc6cc {
            debugLog("breakpoint entry")
        }
        OPCODE = mem.getByte()
        switch OPCODE {
        case 0x00: nop()
        case 0x01: ld_imm(&regs.BC, "BC")
        case 0x02: ld_mem(addr: regs.BC, val: regs.A, "(BC), A")
        case 0x03: inc(&regs.BC, "BC")
        case 0x04: inc(&regs.B, "B")
        case 0x05: dec(&regs.B, "B")
        case 0x06: ld_imm(&regs.B, "B")
        case 0x08:
            let tar = mem.getHalfWord()
            ld_mem(addr: tar, val: UInt8(mem.SP & 0b1111_1111), "SP lo")
            ld_mem(addr: tar + 1, val: UInt8(mem.SP >> 8), "SP hi")
        case 0x09: add(regs.BC)
        case 0x0b: dec(&regs.BC, "BC")
        case 0x0c: inc(&regs.C, "C")
        case 0x0d: dec(&regs.C, "C")
        case 0x0e: ld_imm(&regs.C, "C")
        case 0x10:
            print("STOP instruction encountered")
            exit(1)
        case 0x11: ld_imm(&regs.DE, "DE")
        case 0x12: ld_mem(addr: regs.DE, val: regs.A, "(DE), A")
        case 0x13: inc(&regs.DE, "DE")
        case 0x14: inc(&regs.D, "D")
        case 0x15: dec(&regs.D, "D")
        case 0x16: ld_imm(&regs.D, "D")
        case 0x17: rla()
        case 0x18: jr(condition: true, offset: mem.getSignedByte())
        case 0x19: add(regs.DE)
        case 0x1a: ld_mem(&regs.A, val: mem.read(addr: regs.DE), desc: " A, (DE) - (\(regs.DE.hex))[\(mem.read(addr: regs.DE).hex)]")
        case 0x1b: dec(&regs.DE, "DE")
        case 0x1c: inc(&regs.E, "E")
        case 0x1d: dec(&regs.E, "E")
        case 0x1e: ld_imm(&regs.E, "E")
        case 0x1f: rra()
        case 0x20: jr(condition: !regs.flags.Z, offset: mem.getSignedByte())
        case 0x21: ld_imm(&regs.HL, "HL")
        case 0x22:
            ld_mem(addr: regs.HL, val: regs.A, "A")
            regs.HL += 1
        case 0x23: inc(&regs.HL, "HL")
        case 0x24: inc(&regs.H, "H")
        case 0x25: dec(&regs.H, "H")
        case 0x26: ld_imm(&regs.H, "H")
        case 0x28: jr(condition: regs.flags.Z, offset: mem.getSignedByte())
        case 0x29: add(regs.HL)
        case 0x2a:
            ld_mem(&regs.A, val: mem.read(addr: regs.HL), desc: " A, (HL+) - (\(regs.HL.hex))[\(mem.read(addr: regs.HL).hex)]")
            regs.HL += 1
        case 0x2b: dec(&regs.HL, "HL")
        case 0x2c: inc(&regs.L, "L")
        case 0x2d: dec(&regs.L, "L")
        case 0x2e: ld_imm(&regs.L, "L")
        case 0x30: jr(condition: !regs.flags.C, offset: mem.getSignedByte())
        case 0x31: ld_imm(&mem.SP, "SP")
        case 0x32:
            ld_mem(addr: regs.HL, val: regs.A, "A")
            regs.HL -= 1
        case 0x35: dec(&mem.memory[Int(regs.HL)], "(HL)")
        case 0x36: ld_mem(addr: regs.HL, val: mem.getByte(), "(HL), u8")
        case 0x38: jr(condition: regs.flags.C, offset: mem.getSignedByte())
        case 0x39: add(mem.SP)
        case 0x3c: inc(&regs.A, "A")
        case 0x3d: dec(&regs.A, "A")
        case 0x3e: ld_imm(&regs.A, "A")
        case 0x40: ld_mem(&regs.B, val: regs.B)
        case 0x41: ld_mem(&regs.B, val: regs.C)
        case 0x42: ld_mem(&regs.B, val: regs.D)
        case 0x43: ld_mem(&regs.B, val: regs.E)
        case 0x44: ld_mem(&regs.B, val: regs.H)
        case 0x45: ld_mem(&regs.B, val: regs.L)
        case 0x46: ld_mem(&regs.B, val: mem.read(addr: regs.HL))
        case 0x47: ld_mem(&regs.B, val: regs.A)
        case 0x48: ld_mem(&regs.C, val: regs.B)
        case 0x49: ld_mem(&regs.C, val: regs.C)
        case 0x4a: ld_mem(&regs.C, val: regs.D)
        case 0x4b: ld_mem(&regs.C, val: regs.E)
        case 0x4c: ld_mem(&regs.C, val: regs.H)
        case 0x4d: ld_mem(&regs.C, val: regs.L)
        case 0x4e: ld_mem(&regs.C, val: mem.read(addr: regs.HL))
        case 0x4f: ld_mem(&regs.C, val: regs.A)
        case 0x50: ld_mem(&regs.D, val: regs.B)
        case 0x51: ld_mem(&regs.D, val: regs.C)
        case 0x52: ld_mem(&regs.D, val: regs.D)
        case 0x53: ld_mem(&regs.D, val: regs.E)
        case 0x54: ld_mem(&regs.D, val: regs.H)
        case 0x55: ld_mem(&regs.D, val: regs.L)
        case 0x56: ld_mem(&regs.D, val: mem.read(addr: regs.HL))
        case 0x57: ld_mem(&regs.D, val: regs.A)
        case 0x58: ld_mem(&regs.E, val: regs.B)
        case 0x59: ld_mem(&regs.E, val: regs.C)
        case 0x5a: ld_mem(&regs.E, val: regs.D)
        case 0x5b: ld_mem(&regs.E, val: regs.E)
        case 0x5c: ld_mem(&regs.E, val: regs.H)
        case 0x5d: ld_mem(&regs.E, val: regs.L)
        case 0x5e: ld_mem(&regs.E, val: mem.read(addr: regs.HL))
        case 0x5f: ld_mem(&regs.E, val: regs.A)
        case 0x60: ld_mem(&regs.H, val: regs.B)
        case 0x61: ld_mem(&regs.H, val: regs.C)
        case 0x62: ld_mem(&regs.H, val: regs.D)
        case 0x63: ld_mem(&regs.H, val: regs.E)
        case 0x64: ld_mem(&regs.H, val: regs.H)
        case 0x65: ld_mem(&regs.H, val: regs.L)
        case 0x66: ld_mem(&regs.H, val: mem.read(addr: regs.HL))
        case 0x67: ld_mem(&regs.H, val: regs.A)
        case 0x68: ld_mem(&regs.L, val: regs.B)
        case 0x69: ld_mem(&regs.L, val: regs.C)
        case 0x6a: ld_mem(&regs.L, val: regs.D)
        case 0x6b: ld_mem(&regs.L, val: regs.E)
        case 0x6c: ld_mem(&regs.L, val: regs.H)
        case 0x6d: ld_mem(&regs.L, val: regs.L)
        case 0x6e: ld_mem(&regs.L, val: mem.read(addr: regs.HL))
        case 0x6f: ld_mem(&regs.L, val: regs.A)
        case 0x70: ld_mem(addr: regs.HL, val: regs.B, "B")
        case 0x71: ld_mem(addr: regs.HL, val: regs.C, "C")
        case 0x72: ld_mem(addr: regs.HL, val: regs.D, "D")
        case 0x73: ld_mem(addr: regs.HL, val: regs.E, "E")
        case 0x74: ld_mem(addr: regs.HL, val: regs.H, "H")
        case 0x75: ld_mem(addr: regs.HL, val: regs.L, "L")
        case 0x77: ld_mem(addr: regs.HL, val: regs.A, "A")
        case 0x78: ld_mem(&regs.A, val: regs.B)
        case 0x79: ld_mem(&regs.A, val: regs.C)
        case 0x7a: ld_mem(&regs.A, val: regs.D)
        case 0x7b: ld_mem(&regs.A, val: regs.E)
        case 0x7c: ld_mem(&regs.A, val: regs.H)
        case 0x7d: ld_mem(&regs.A, val: regs.L)
        case 0x7e: ld_mem(&regs.A, val: mem.read(addr: regs.HL))
        case 0x7f: ld_mem(&regs.A, val: regs.A)
        case 0x86: add(mem.read(addr: regs.HL))
        case 0x88: adc(regs.B)
        case 0x89: adc(regs.C)
        case 0x8a: adc(regs.D)
        case 0x8b: adc(regs.E)
        case 0x8c: adc(regs.H)
        case 0x8d: adc(regs.L)
        case 0x8f: adc(regs.A)
        case 0x90: sub(regs.B)
        case 0x91: sub(regs.C)
        case 0x92: sub(regs.D)
        case 0x93: sub(regs.E)
        case 0x94: sub(regs.H)
        case 0x95: sub(regs.L)
        case 0x96: sub(mem.read(addr: regs.HL))
        case 0x97: sub(regs.A)
        case 0xa8: xor(regs.B)
        case 0xa9: xor(regs.C)
        case 0xaa: xor(regs.D)
        case 0xab: xor(regs.E)
        case 0xac: xor(regs.H)
        case 0xad: xor(regs.L)
        case 0xae: xor(mem.read(addr: regs.HL))
        case 0xaf: xor(regs.A)
        case 0xb0: or(regs.B)
        case 0xb1: or(regs.C)
        case 0xb2: or(regs.D)
        case 0xb3: or(regs.E)
        case 0xb4: or(regs.H)
        case 0xb5: or(regs.L)
        case 0xb6: or(mem.read(addr: regs.HL))
        case 0xb7: or(regs.A)
        case 0xbe: cp(regs.A, val: mem.read(addr: regs.HL), "(HL)[\(mem.read(addr: regs.HL).hex)]")
        case 0xc0: ret(condition: !regs.flags.Z)
        case 0xc1:
            regs.C = mem.read(addr: mem.SP)
            mem.SP+=1
            regs.B = mem.read(addr: mem.SP)
            mem.SP+=1
        case 0xc2: jmp(condition: !regs.flags.Z, address: mem.getHalfWord())
        case 0xc3: jmp(condition: true, address: mem.getHalfWord())
        case 0xc4: call(condition: !regs.flags.Z)
        case 0xc5:
            mem.SP-=1
            ld_mem(addr: mem.SP, val: regs.B, "B")
            mem.SP-=1
            ld_mem(addr: mem.SP, val: regs.C, "C")
        case 0xc6: add(mem.getByte())
        case 0xc7: rst(0x0000)
        case 0xc8: ret(condition: regs.flags.Z)
        case 0xc9: ret(condition: true)
        case 0xca: jmp(condition: regs.flags.Z, address: mem.getHalfWord())
        case 0xcb:
            let CB = mem.getByte()
            let reg: UnsafeMutablePointer<UInt8> = {
                switch (CB & 0b0111) {
                case 0b0000: return .init(&regs.B)
                case 0b0001: return .init(&regs.C)
                case 0b0010: return .init(&regs.D)
                case 0b0011: return .init(&regs.E)
                case 0b0100: return .init(&regs.H)
                case 0b0101: return .init(&regs.L)
                case 0b0110: return .init(&mem.memory[Int(regs.HL)])
                case 0b0111: return .init(&regs.A)
                default:
                    print("Fatal error while decoding CB instruction")
                    exit(1)
                }
            }()
            let CB_HI = (CB & 0b1111_1000)
            switch CB_HI {
            case 0x10: rl(&reg.pointee)
            case 0x18: rr(&reg.pointee)
            case 0x30: swap(&reg.pointee)
            case 0x38: srl(&reg.pointee)
            case 0x78: bit(&reg.pointee, (CB_HI>>3)&0b111)
            default:
                print("Unsupported CB Opcode \(CB.hex) at location \(mem.PC.hex)")
                print("Follow up bytes: \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) ")
                exit(1)
            }
        case 0xcc: call(condition: regs.flags.Z)
        case 0xcd: call(condition: true)
        case 0xce: adc(mem.getByte())
        case 0xcf: rst(0x0008)
        case 0xd0: ret(condition: !regs.flags.C)
        case 0xd1: pop(&regs.DE, "DE")
        case 0xd2: jmp(condition: !regs.flags.C, address: mem.getHalfWord())
        case 0xd4: call(condition: !regs.flags.C)
        case 0xd5: push(regs.DE, "DE")
        case 0xd6: sub(mem.getByte())
        case 0xd7: rst(0x0010)
        case 0xd8: ret(condition: regs.flags.C)
        case 0xd9: ret(condition: true, enable_interrupts: true)
        case 0xda: jmp(condition: regs.flags.C, address: mem.getHalfWord())
        case 0xdc: call(condition: regs.flags.C)
        case 0xdf: rst(0x0018)
        case 0xe0: ld_mem(addr: 0xFF00 + UInt16(mem.getByte()), val: regs.A, "A")
        case 0xe1: pop(&regs.HL, "HL")
        case 0xe2: ld_mem(addr: 0xFF00 + UInt16(regs.C), val: regs.A, "A")
        case 0xe5: push(regs.HL, "HL")
        case 0xe6: and(mem.getByte())
        case 0xe7: rst(0x0020)
        case 0xe9: jmp(condition: true, address: regs.HL)
        case 0xea: ld_mem(addr: mem.getHalfWord(), val: regs.A, "(u16) A")
        case 0xee: xor(mem.getByte())
        case 0xef: rst(0x0028)
        case 0xf0: ld_mem(&regs.A, val: mem.read(addr: 0xFF00 + UInt16(mem.getByte())))
        case 0xf1: pop(&regs.AF, "AF")
        case 0xf2: ld_mem(&regs.A, val: mem.read(addr: 0xFF00 + UInt16(regs.C)))
        case 0xf3: interrupts_enabled = false
        case 0xf5: push(regs.AF, "AF")
        case 0xf6: or(mem.getByte())
        case 0xf7: rst(0x0030)
        case 0xf9: mem.SP = regs.HL
        case 0xfa: ld_mem(&regs.A, val: mem.read(addr: mem.getHalfWord()))
        case 0xfb: interrupts_enabled = true
        case 0xfe: cp(regs.A, val: mem.getByte(), "A, u8")
        case 0xff: rst(0x0038)
        default:
            print("Unsupported Opcode \(OPCODE.hex) at location \(mem.PC.hex)")
            print("Follow up bytes: \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) ")
            exit(1)
        }
    }
    
    func rst(_ a: UInt16) {
        push(mem.PC, "PC")
        mem.PC = a
        debugLog("RST \(a.hex)")
    }
    
    func ret(condition: Bool, enable_interrupts: Bool = false) {
        if (condition) {    //  yes this is correct, branch decision comes before fetching target address bytes
            let lo = mem.read(addr: mem.SP)
            mem.SP += 1
            let hi = mem.read(addr: mem.SP)
            mem.SP += 1
            mem.PC = UInt16(hi) * 0x100 + UInt16(lo)
            if (enable_interrupts) {
                interrupts_enabled = true
            }
        }
        debugLog("RET \(mem.PC.hex)")
    }
    
    func nop() {
        debugLog("NOP")
    }
    
    func call(condition: Bool) {
        let tar = mem.getHalfWord()
        if condition {
            mem.SP-=1
            mem.write(addr: mem.SP, val: mem.PC.hiByte)
            mem.SP-=1
            mem.write(addr: mem.SP, val: mem.PC.loByte)
            mem.PC = tar
        }
        debugLog("CALL u16, (\(mem.PC.hex))")
    }
    
    func ld_mem(_ tar: inout UInt8, val: UInt8, desc: String = "") {
        tar = val
        debugLog("LD \(desc)")
    }
    
    func ld_mem(addr: UInt16, val: UInt8, _ desc: String) {
        if addr == 0xd81e {
            debugLog("break me daddy uwu")
        }
        mem.write(addr: addr, val: val)
        debugLog("LD (\(addr.hex)), \(desc) (\(val))")
    }
    
    //  ld immediate - BYTE
    func ld_imm(_ tar: inout UInt8, _ desc: String) {
        tar = mem.getByte()
        debugLog("LD \(desc), \(tar.hex)")
    }
    
    //  ld immediate - WORD
    func ld_imm(_ tar: inout UInt16, _ desc: String) {
        let lo = mem.getByte()
        let hi = mem.getByte()
        tar = UInt16(hi) * 0x100 &+ UInt16(lo)
        debugLog("LD \(desc), \(tar.hex)")
    }
    
    //  non-CB
    func rla() {
        regs.flags.C = (regs.A & 0b1000_0000) > 0
        regs.A <<= 1
        debugLog("RLA")
    }
    
    func inc(_ a: inout UInt8, _ desc: String) {
        regs.flags.H = (a & 0b1111) == 0b1111
        a &+= 1
        regs.flags.N = false
        regs.flags.Z = a == 0
        debugLog("INC \(desc)")
    }
    
    func inc(_ a: inout UInt16, _ desc: String) {
        a &+= 1
        debugLog("INC \(desc)")
    }
    
    func dec(_ a: inout UInt8, _ desc: String) {
        regs.flags.H = (a & 0b1111) == 0b0000
        a &-= 1
        regs.flags.N = true
        regs.flags.Z = a == 0
        debugLog("DEC \(desc)")
    }
    
    func dec(_ a: inout UInt16, _ desc: String) {
        a &-= 1
        debugLog("DEC \(desc)")
    }
    
    func xor(_ a: UInt8) {
        regs.A = regs.A ^ a
        regs.flags.Z = regs.A == 0
        regs.flags.N = false
        regs.flags.H = false
        regs.flags.C = false
        debugLog("XOR, (\(a)) - (Z: \(regs.flags.Z))")
    }
    
    func or(_ a: UInt8) {
        regs.A = regs.A | a
        regs.flags.Z = regs.A == 0
        regs.flags.N = false
        regs.flags.H = false
        regs.flags.C = false
        debugLog("OR, (\(a)) - (Z: \(regs.flags.Z))")
    }
    
    func and(_ a: UInt8) {
        regs.A = regs.A & a
        regs.flags.Z = regs.A == 0
        regs.flags.N = false
        regs.flags.H = true
        regs.flags.C = false
        debugLog("AND, (\(a)) - (Z: \(regs.flags.Z))")
    }
    
    func cp(_ a: UInt8, val: UInt8, _ desc: String) {
        regs.flags.Z = a == val
        regs.flags.N = true
        regs.flags.H = (a & 0b1111) < (val & 0b1111)
        regs.flags.C = a < val
        debugLog("CP \(desc)")
    }
    
    func push(_ w: UInt16, _ desc: String) {
        mem.SP -= 1
        mem.write(addr: mem.SP, val: w.hiByte)
        mem.SP -= 1
        mem.write(addr: mem.SP, val: w.loByte)
        debugLog("PUSH \(desc)")
    }
    
    func pop(_ w: inout UInt16, _ desc: String) {
        let lo = mem.read(addr: mem.SP)
        mem.SP += 1
        let hi = mem.read(addr: mem.SP)
        mem.SP += 1
        w = (UInt16(hi) << 8) | UInt16(lo)
        debugLog("POP \(desc)")
    }
    
    func jmp(condition: Bool, address: UInt16) {
        if condition {
            mem.PC = address
        }
        debugLog("JMP")
    }
    
    func jr(condition: Bool, offset: Int8) {
        if condition {
            mem.PC = UInt16(Int(mem.PC) + Int(offset))
        }
        debugLog("JR, (\(offset))")
    }
    
    func sub(_ val: UInt8) {
        regs.flags.C = val > regs.A
        regs.flags.H = (val & 0xf) > (regs.A & 0xf)
        regs.A = regs.A &- val
        regs.flags.Z = regs.A == 0
        regs.flags.N = true
        debugLog("SUB \(val)")
    }
    
    func add(_ val: UInt8) {
        regs.flags.C = (UInt16(val) + UInt16(regs.A)) > 0xff
        regs.flags.H = (UInt16(val & 0xf) + UInt16(regs.A & 0xf)) > 0xf
        regs.A = regs.A &+ val
        regs.flags.Z = regs.A == 0
        regs.flags.N = false
        debugLog("ADD \(val)")
    }
    
    func add(_ val: UInt16) {
        regs.flags.C = (val &+ regs.HL) > 0xff
        regs.flags.H = ((val & 0xf) &+ (regs.HL & 0xf)) > 0xf
        regs.HL = regs.HL &+ val
        regs.flags.N = false
        debugLog("ADD \(val)")
    }
    
    func adc(_ val: UInt8) {
        regs.flags.N = false;
        regs.flags.H = ((UInt16(val & 0xf) + UInt16(regs.A & 0xf) + UInt16(regs.flags.C ? 1 : 0)) > 0xf)
        let oldcarry = ((UInt16(val) + UInt16(regs.A) + UInt16(regs.flags.C ? 1 : 0)) > 0xff)
        regs.A &+= val &+ UInt8(regs.flags.C ? 1 : 0)
        regs.flags.C = oldcarry
        regs.flags.Z = regs.A == 0
        debugLog("ADC \(val)")
    }
    
    func rra(rrca: Bool = false) {
        let oldcarry: UInt8 = regs.flags.C ? 1 : 0
        regs.flags.C = (regs.A & 1) > 0
        regs.flags.Z = false
        regs.flags.N = false
        regs.flags.H = false
        if rrca {
            regs.A = (regs.A >> 1) | (oldcarry << 7)
            debugLog("RRCA")
        } else {
            regs.A = (regs.A >> 1) | ((regs.flags.C ? 1 : 0) << 7)
            debugLog("RRA")
        }
    }
    
    //  CB
    func srl(_ a: inout UInt8) {
        regs.flags.C = (a & 1) > 0
        regs.flags.N = false
        regs.flags.H = false
        a = a >> 1
        regs.flags.Z = a == 0
        debugLog("SRL")
    }
    
    func bit(_ a: inout UInt8, _ bit: UInt8) {
        regs.flags.Z = (a & (1<<bit)) == 0
        regs.flags.N = false
        regs.flags.H = true
        debugLog("BIT \(bit)")
    }
    
    func rl(_ a: inout UInt8) {
        let oldcarry: UInt8 = regs.flags.C ? 1 : 0
        regs.flags.C = (a >> 7) > 0
        regs.flags.N = false
        regs.flags.H = false
        a = (a << 1) | oldcarry
        regs.flags.Z = a == 0
        debugLog("RL")
    }
    
    func rr(_ a: inout UInt8) {
        let oldcarry: UInt8 = regs.flags.C ? 1 : 0
        regs.flags.C = (a & 1) > 0
        regs.flags.N = false
        regs.flags.H = false
        a = (a >> 1) | (oldcarry << 7)
        regs.flags.Z = a == 0;
        debugLog("RR")
    }
    
    func swap(_ a: inout UInt8) {
        regs.flags.C = false
        regs.flags.N = false
        regs.flags.H = false
        a = (a >> 4) | ((a & 0b1111) << 4)
        regs.flags.Z = a == 0
    }
}

func debugLog(_ msg: String, terminator: String = "\n") {
//    print(msg, terminator: terminator)
}
