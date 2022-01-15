import Darwin
import CoreFoundation
import SwiftUI

//      GAMEBOY
//  Main RAM: 8K Byte
//  Video RAM: 8K Byte
//  Resolution: 160x144 (20x18 tiles)
//  Max # of Sprites: 40
//  Max # of Sprites/line: 10
//  Clock speed: 4.194304 MHz

class REGS {

    public var flags : FLAGS = FLAGS()
    public var A: UInt8 = 0,B: UInt8 = 0,C: UInt8 = 0,D: UInt8 = 0,E: UInt8 = 0,H: UInt8 = 0,L: UInt8 = 0
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
}

class FLAGS {
    public var Z:Bool = false,N:Bool = false,H:Bool = false,C:Bool = false,HALT:Bool = false
}

class CPU {
    
    private var OPCODE : UInt8 = 0x00
    private var mem : MEMORY
    public var regs : REGS
    public var interrupts_enabled : Bool = false
    
    init(mem: MEMORY) {
        self.mem = mem
        self.regs = REGS()
        EMULATOR.debugLog("setting up CPU", level: .ERROR)
    }

    func step() {
        //  check OPCODE
        EMULATOR.debugLog("\(mem.PC.hex) [SP: \(mem.SP.hex)][HL: \(regs.HL.hex)][\(regs.flags.Z ? "Z":"-")\(regs.flags.N ? "N":"-")\(regs.flags.H ? "H":"-")\(regs.flags.C ? "C":"-")][A: \(regs.A.hex) B: \(regs.B.hex)] - ", terminator: "")
        OPCODE = mem.getByte()
        let r: UnsafeMutablePointer<UInt8> = {
            [.init(&regs.B), .init(&regs.C), .init(&regs.D), .init(&regs.E), .init(&regs.H), .init(&regs.L), .init(&mem.memory[Int(regs.HL)]), .init(&regs.A)][Int(OPCODE) & 0b0111]
        }()
        switch OPCODE {
        case 0x00: nop()
        case 0x01: ld_imm(&regs.BC, "BC")
        case 0x02: ld_mem(addr: regs.BC, val: regs.A)
        case 0x03: inc(&regs.BC, "BC")
        case 0x04: inc(&regs.B, "")
        case 0x05: dec(&regs.B, "B")
        case 0x06: ld_imm(&regs.B, "B")
        case 0x07: rla(rlca: true)
        case 0x08:
            let tar = mem.getHalfWord()
            ld_mem(addr: tar, val: UInt8(mem.SP & 0b1111_1111))
            ld_mem(addr: tar + 1, val: UInt8(mem.SP >> 8))
        case 0x09: add(regs.BC)
        case 0x0a: ld_mem(&regs.A, val: mem.read(addr: regs.BC))
        case 0x0b: dec(&regs.BC, "BC")
        case 0x0c: inc(&regs.C, "C")
        case 0x0d: dec(&regs.C, "C")
        case 0x0e: ld_imm(&regs.C, "C")
        case 0x0f: rra(rrca: true)
        case 0x10:
            print("STOP instruction encountered")
            exit(1)
        case 0x11: ld_imm(&regs.DE, "DE")
        case 0x12: ld_mem(addr: regs.DE, val: regs.A)
        case 0x13: inc(&regs.DE, "DE")
        case 0x14: inc(&regs.D, "D")
        case 0x15: dec(&regs.D, "D")
        case 0x16: ld_imm(&regs.D, "D")
        case 0x17: rla()
        case 0x18: jr(condition: true, offset: mem.getSignedByte())
        case 0x19: add(regs.DE)
        case 0x1a: ld_mem(&regs.A, val: mem.read(addr: regs.DE))
        case 0x1b: dec(&regs.DE, "DE")
        case 0x1c: inc(&regs.E, "E")
        case 0x1d: dec(&regs.E, "E")
        case 0x1e: ld_imm(&regs.E, "E")
        case 0x1f: rra()
        case 0x20: jr(condition: !regs.flags.Z, offset: mem.getSignedByte())
        case 0x21: ld_imm(&regs.HL, "HL")
        case 0x22:
            ld_mem(addr: regs.HL, val: regs.A)
            regs.HL += 1
        case 0x23: inc(&regs.HL, "HL")
        case 0x24: inc(&regs.H, "H")
        case 0x25: dec(&regs.H, "H")
        case 0x26: ld_imm(&regs.H, "H")
        case 0x27: daa()
        case 0x28: jr(condition: regs.flags.Z, offset: mem.getSignedByte())
        case 0x29: add(regs.HL)
        case 0x2a:
            ld_mem(&regs.A, val: mem.read(addr: regs.HL))
            regs.HL += 1
        case 0x2b: dec(&regs.HL, "HL")
        case 0x2c: inc(&regs.L, "L")
        case 0x2d: dec(&regs.L, "L")
        case 0x2e: ld_imm(&regs.L, "L")
        case 0x2f: cpl()
        case 0x30: jr(condition: !regs.flags.C, offset: mem.getSignedByte())
        case 0x31: ld_imm(&mem.SP, "SP")
        case 0x32:
            ld_mem(addr: regs.HL, val: regs.A)
            regs.HL -= 1
        case 0x33: inc(&mem.SP, "SP")
        case 0x34: inc(&mem.memory[Int(regs.HL)], "(HL)")
        case 0x35: dec(&mem.memory[Int(regs.HL)], "(HL)")
        case 0x36: ld_mem(addr: regs.HL, val: mem.getByte())
        case 0x37: cf(true)
        case 0x38: jr(condition: regs.flags.C, offset: mem.getSignedByte())
        case 0x39: add(mem.SP)
        case 0x3a:
            ld_mem(&regs.A, val: mem.read(addr: regs.HL))
            regs.HL -= 1
        case 0x3b: dec(&mem.SP, "SP")
        case 0x3c: inc(&regs.A, "A")
        case 0x3d: dec(&regs.A, "A")
        case 0x3e: ld_imm(&regs.A, "A")
        case 0x3f: cf(!regs.flags.C)
        case 0x40...0x47: ld_mem(&regs.B, val: r.pointee)
        case 0x48...0x4f: ld_mem(&regs.C, val: r.pointee)
        case 0x50...0x57: ld_mem(&regs.D, val: r.pointee)
        case 0x58...0x5f: ld_mem(&regs.E, val: r.pointee)
        case 0x60...0x67: ld_mem(&regs.H, val: r.pointee)
        case 0x68...0x6f: ld_mem(&regs.L, val: r.pointee)
        case 0x70...0x75: ld_mem(addr: regs.HL, val: r.pointee)
        case 0x76: regs.flags.HALT = true
        case 0x77: ld_mem(addr: regs.HL, val: r.pointee)
        case 0x78...0x7f: ld_mem(&regs.A, val: r.pointee)
        case 0x80...0x87: add(r.pointee)
        case 0x88...0x8f: adc(r.pointee)
        case 0x90...0x97: sub(r.pointee)
        case 0x98...0x9f: sbc(r.pointee)
        case 0xa0...0xa7: and(r.pointee)
        case 0xa8...0xaf: xor(r.pointee)
        case 0xb0...0xb7: or(r.pointee)
        case 0xb8...0xbf: cp(r.pointee)
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
            ld_mem(addr: mem.SP, val: regs.B)
            mem.SP-=1
            ld_mem(addr: mem.SP, val: regs.C)
        case 0xc6: add(mem.getByte())
        case 0xc7: rst(0x0000)
        case 0xc8: ret(condition: regs.flags.Z)
        case 0xc9: ret(condition: true)
        case 0xca: jmp(condition: regs.flags.Z, address: mem.getHalfWord())
        case 0xcb:
            let CB = mem.getByte()
            let reg: UnsafeMutablePointer<UInt8> = {
                [.init(&regs.B), .init(&regs.C), .init(&regs.D), .init(&regs.E), .init(&regs.H), .init(&regs.L), .init(&mem.memory[Int(regs.HL)]), .init(&regs.A)][Int(CB) & 0b0111]
            }()
            let CB_HI = (CB & 0b1111_1000)
            switch CB_HI {
            case 0x00: rl(&reg.pointee, keep_carry: true)
            case 0x08: rr(&reg.pointee, keep_carry: true)
            case 0x10: rl(&reg.pointee)
            case 0x18: rr(&reg.pointee)
            case 0x20: rl(&reg.pointee, carry_any: false)
            case 0x28: rr(&reg.pointee, carry_any: false)
            case 0x30: swap(&reg.pointee)
            case 0x38: srl(&reg.pointee)
            case 0x40...0x7f: bit(&reg.pointee, (CB_HI>>3)&0b111)
            case 0x80...0xbf: res(&reg.pointee, (CB_HI>>3)&0b111)
            case 0xc0...0xff: set(&reg.pointee, (CB_HI>>3)&0b111)
            default:
                EMULATOR.debugLog("Unsupported CB Opcode \(CB.hex) at location \(mem.PC.hex)", level: .ERROR)
                EMULATOR.debugLog("Follow up bytes: \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) ", level: .ERROR)
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
        case 0xde: sbc(mem.getByte())
        case 0xdf: rst(0x0018)
        case 0xe0: ld_mem(addr: 0xFF00 + UInt16(mem.getByte()), val: regs.A)
        case 0xe1: pop(&regs.HL, "HL")
        case 0xe2: ld_mem(addr: 0xFF00 + UInt16(regs.C), val: regs.A)
        case 0xe5: push(regs.HL, "HL")
        case 0xe6: and(mem.getByte())
        case 0xe7: rst(0x0020)
        case 0xe8: add_sp()
        case 0xe9: jmp(condition: true, address: regs.HL)
        case 0xea: ld_mem(addr: mem.getHalfWord(), val: regs.A)
        case 0xee: xor(mem.getByte())
        case 0xef: rst(0x0028)
        case 0xf0: ld_mem(&regs.A, val: mem.read(addr: 0xFF00 + UInt16(mem.getByte())))
        case 0xf1: pop(&regs.AF, "AF")
        case 0xf2: ld_mem(&regs.A, val: mem.read(addr: 0xFF00 + UInt16(regs.C)))
        case 0xf3: interrupts_enabled = false
        case 0xf5: push(regs.AF, "AF")
        case 0xf6: or(mem.getByte())
        case 0xf7: rst(0x0030)
        case 0xf8: ld_hl_sp_i()
        case 0xf9: mem.SP = regs.HL
        case 0xfa: ld_mem(&regs.A, val: mem.read(addr: mem.getHalfWord()))
        case 0xfb: interrupts_enabled = true
        case 0xfe: cp(mem.getByte(), "A, u8")
        case 0xff: rst(0x0038)
        default:
            EMULATOR.debugLog("Unsupported Opcode \(OPCODE.hex) at location \(mem.PC.hex)", level: .ERROR)
            EMULATOR.debugLog("Follow up bytes: \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) \(mem.getByte().hex) ", level: .ERROR)
            exit(1)
        }
    }
    
    func rst(_ a: UInt16) {
        push(mem.PC, "PC")
        mem.PC = a
        EMULATOR.debugLog("RST \(a.hex)")
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
        EMULATOR.debugLog("RET \(mem.PC.hex)")
    }
    
    func nop() {
        EMULATOR.debugLog("NOP")
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
        EMULATOR.debugLog("CALL u16, (\(mem.PC.hex))")
    }
    
    func ld_mem(_ tar: inout UInt8, val: UInt8, desc: String = "") {
        tar = val
        EMULATOR.debugLog("LD \(desc)")
    }
    
    func ld_mem(addr: UInt16, val: UInt8) {
        mem.write(addr: addr, val: val)
        EMULATOR.debugLog("LD (\(addr.hex)), (\(val))")
    }
    
    //  ld immediate - BYTE
    func ld_imm(_ tar: inout UInt8, _ desc: String) {
        tar = mem.getByte()
        EMULATOR.debugLog("LD \(desc), \(tar.hex)")
    }
    
    //  ld immediate - WORD
    func ld_imm(_ tar: inout UInt16, _ desc: String) {
        let lo = mem.getByte()
        let hi = mem.getByte()
        tar = UInt16(hi) * 0x100 &+ UInt16(lo)
        EMULATOR.debugLog("LD \(desc), \(tar.hex)")
    }
    
    func inc(_ a: inout UInt8, _ desc: String) {
        regs.flags.H = (a & 0b1111) == 0b1111
        a &+= 1
        regs.flags.N = false
        regs.flags.Z = a == 0
        EMULATOR.debugLog("INC \(desc)")
    }
    
    func inc(_ a: inout UInt16, _ desc: String) {
        a &+= 1
        EMULATOR.debugLog("INC \(desc)")
    }
    
    func dec(_ a: inout UInt8, _ desc: String) {
        regs.flags.H = (a & 0b1111) == 0b0000
        a &-= 1
        regs.flags.N = true
        regs.flags.Z = a == 0
        EMULATOR.debugLog("DEC \(desc)")
    }
    
    func dec(_ a: inout UInt16, _ desc: String) {
        a &-= 1
        EMULATOR.debugLog("DEC \(desc)")
    }
    
    func xor(_ a: UInt8) {
        regs.A = regs.A ^ a
        regs.flags.Z = regs.A == 0
        regs.flags.N = false
        regs.flags.H = false
        regs.flags.C = false
        EMULATOR.debugLog("XOR, (\(a)) - (Z: \(regs.flags.Z))")
    }
    
    func or(_ a: UInt8) {
        regs.A = regs.A | a
        regs.flags.Z = regs.A == 0
        regs.flags.N = false
        regs.flags.H = false
        regs.flags.C = false
        EMULATOR.debugLog("OR, (\(a)) - (Z: \(regs.flags.Z))")
    }
    
    func and(_ a: UInt8) {
        regs.A = regs.A & a
        regs.flags.Z = regs.A == 0
        regs.flags.N = false
        regs.flags.H = true
        regs.flags.C = false
        EMULATOR.debugLog("AND, (\(a)) - (Z: \(regs.flags.Z))")
    }
    
    func cp(_ val: UInt8, _ desc: String = "") {
        regs.flags.Z = regs.A == val
        regs.flags.N = true
        regs.flags.H = regs.A.lowerNibble < val.lowerNibble
        regs.flags.C = regs.A < val
        EMULATOR.debugLog("CP \(desc)")
    }
    
    func push(_ w: UInt16, _ desc: String) {
        mem.SP -= 1
        mem.write(addr: mem.SP, val: w.hiByte)
        mem.SP -= 1
        mem.write(addr: mem.SP, val: w.loByte)
        EMULATOR.debugLog("PUSH \(desc)")
    }
    
    func pop(_ w: inout UInt16, _ desc: String) {
        let lo = mem.read(addr: mem.SP)
        mem.SP += 1
        let hi = mem.read(addr: mem.SP)
        mem.SP += 1
        w = (UInt16(hi) << 8) | UInt16(lo)
        EMULATOR.debugLog("POP \(desc)")
    }
    
    func jmp(condition: Bool, address: UInt16) {
        if condition {
            mem.PC = address
        }
        EMULATOR.debugLog("JMP")
    }
    
    func jr(condition: Bool, offset: Int8) {
        if condition {
            mem.PC = UInt16(Int(mem.PC) + Int(offset))
        }
        EMULATOR.debugLog("JR, (\(offset))")
    }
    
    func sub(_ val: UInt8) {
        regs.flags.C = val > regs.A
        regs.flags.H = (val & 0xf) > (regs.A & 0xf)
        regs.A = regs.A &- val
        regs.flags.Z = regs.A == 0
        regs.flags.N = true
        EMULATOR.debugLog("SUB \(val)")
    }
    
    func sbc(_ val: UInt8) {
        regs.flags.N = true
        let oldcarry = (val.u16 + regs.flags.C.int16) > regs.A
        regs.flags.H = (val.lowerNibble + regs.flags.C.int8) > regs.A.lowerNibble
        regs.A = regs.A &- (val &+ regs.flags.C.int8)
        regs.flags.C = oldcarry
        regs.flags.Z = regs.A == 0
    }
    
    func add(_ val: UInt8) {
        regs.flags.C = (val.u16 + regs.A.u16) > 0xff
        regs.flags.H = (val.lowerNibble.u16 + regs.A.lowerNibble.u16) > 0xf
        regs.A = regs.A &+ val
        regs.flags.Z = regs.A == 0
        regs.flags.N = false
        EMULATOR.debugLog("ADD \(val)")
    }
    
    func add(_ val: UInt16) {
        regs.flags.N = false
        regs.flags.H = (((val & 0xfff) + (regs.HL & 0xfff)) & 0x1000) > 0
        regs.flags.C = (UInt(val) + UInt(regs.HL)) > 0xffff
        regs.HL = regs.HL &+ val
        EMULATOR.debugLog("ADD \(val)")
    }
    
    func add_sp() {           //  calc Flags on UNSIGNED byte, store to SP with SIGNED byte!
        let val = mem.getByte()
        regs.flags.Z = false
        regs.flags.N = false
        regs.flags.H = ((mem.SP & 0xf) + (val.u16 & 0xf)) > 0xf
        regs.flags.C = ((mem.SP & 0xff) + (val.u16 & 0xff)) > 0xff
        mem.SP = UInt16(truncatingIfNeeded: Int(mem.SP) &+ Int(Int8(bitPattern: val)))
        EMULATOR.debugLog("ADD_SP \(val)")
    }
    
    func ld_hl_sp_i() {       //  calc Flags on UNSIGNED byte, store to HL with SIGNED byte!
        let val = mem.getByte()
        regs.flags.H = ((mem.SP & 0xf) + (val.u16 & 0xf)) > 0xf
        regs.flags.C = ((mem.SP & 0xff) + (val.u16 & 0xff)) > 0xff
        regs.HL = UInt16(truncatingIfNeeded: Int(mem.SP) &+ Int(Int8(bitPattern: val)))
        regs.flags.N = false
        regs.flags.Z = false
        EMULATOR.debugLog("LD HL, SP+i")
    }
    
    func adc(_ val: UInt8) {
        regs.flags.N = false;
        regs.flags.H = (val.lowerNibble.u16 + regs.A.lowerNibble.u16 + regs.flags.C.int16) > 0xf
        let oldcarry = (val.u16 + regs.A.u16 + regs.flags.C.int16) > 0xff
        regs.A &+= val &+ regs.flags.C.int8
        regs.flags.C = oldcarry
        regs.flags.Z = regs.A == 0
        EMULATOR.debugLog("ADC \(val)")
    }
    
    func rra(rrca: Bool = false) {
        let oldcarry: UInt8 = regs.flags.C.int8
        regs.flags.C = (regs.A & 1) > 0
        regs.flags.Z = false
        regs.flags.N = false
        regs.flags.H = false
        if !rrca {
            regs.A = (regs.A >> 1) | (oldcarry << 7)
            EMULATOR.debugLog("RRA")
        } else {
            regs.A = (regs.A >> 1) | (regs.flags.C.int8 << 7)
            EMULATOR.debugLog("RRCA")
        }
    }
    
    func rla(rlca: Bool = false) {
        let oldcarry: UInt8 = regs.flags.C.int8
        regs.flags.C = (regs.A & 0b1000_0000) > 0
        regs.flags.Z = false
        regs.flags.N = false
        regs.flags.H = false
        if !rlca {
            regs.A = (regs.A << 1) | oldcarry
            EMULATOR.debugLog("RLA")
        } else {
            regs.A = (regs.A << 1) | regs.flags.C.int8
            EMULATOR.debugLog("RLCA")
        }
    }
    
    func daa() {
        if !regs.flags.N {
            if (regs.flags.C || regs.A > 0x99) {
                regs.A &+= 0x60
                regs.flags.C = true
            }
            if (regs.flags.H || (regs.A & 0x0f) > 0x09) {
                regs.A &+= 0x06
            }
        }
        else {
            if regs.flags.C {
                regs.A &-= 0x60
            }
            if (regs.flags.H) {
                regs.A &-= 0x06
            }
        }
        regs.flags.Z = regs.A == 0
        regs.flags.H = false
    }
    
    func cpl() {
        regs.A = ~regs.A
        regs.flags.N = true
        regs.flags.H = true
    }
    
    func cf(_ a: Bool) {
        regs.flags.H = false
        regs.flags.N = false
        regs.flags.C = a
    }
    
    //  CB
    func srl(_ a: inout UInt8) {
        regs.flags.C = (a & 1) > 0
        regs.flags.N = false
        regs.flags.H = false
        a = a >> 1
        regs.flags.Z = a == 0
        EMULATOR.debugLog("SRL")
    }
    
    func bit(_ a: inout UInt8, _ bit: UInt8) {
        regs.flags.Z = (a & (1<<bit)) == 0
        regs.flags.N = false
        regs.flags.H = true
        EMULATOR.debugLog("BIT \(bit)")
    }
    
    func res(_ a: inout UInt8, _ bit: UInt8) {
        a = a & ~(1<<bit)
        EMULATOR.debugLog("RES \(bit)")
    }
    
    func set(_ a: inout UInt8, _ bit: UInt8) {
        a = a | (1<<bit)
        EMULATOR.debugLog("SET \(bit)")
    }
    
    func rl(_ a: inout UInt8, carry_any: Bool = true, keep_carry: Bool = false) {
        let oldcarry: UInt8 = regs.flags.C.int8
        regs.flags.C = (a >> 7) > 0
        regs.flags.N = false
        regs.flags.H = false
        if carry_any {
            if !keep_carry {
                a = (a << 1) | oldcarry
            } else {
                a = (a << 1) | regs.flags.C.int8
            }
        } else {
            a = (a << 1)
        }
        regs.flags.Z = a == 0
        EMULATOR.debugLog("RL")
    }
    
    func rr(_ a: inout UInt8, carry_any: Bool = true, keep_carry: Bool = false) {
        let oldcarry: UInt8 = regs.flags.C.int8
        let msb: UInt8 = a >> 7
        regs.flags.C = (a & 1) > 0
        regs.flags.N = false
        regs.flags.H = false
        if carry_any {
            if !keep_carry {
                a = (a >> 1) | (oldcarry << 7)
            } else {
                a = (a >> 1) | (regs.flags.C.int8 << 7)
            }
        } else {
            a = (a >> 1) | (msb << 7)
        }
        regs.flags.Z = a == 0;
        EMULATOR.debugLog("RR")
    }
    
    func swap(_ a: inout UInt8) {
        regs.flags.C = false
        regs.flags.N = false
        regs.flags.H = false
        a = (a >> 4) | ((a & 0b1111) << 4)
        regs.flags.Z = a == 0
    }
    
}
