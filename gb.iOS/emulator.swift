//
//  main.swift
//  gb.iOS
//
//  Created by Jan on 06.01.22.
//

import SwiftUI

//      GAMEBOY
//  Main RAM: 8K Byte
//  Video RAM: 8K Byte
//  Resolution: 160x144 (20x18 tiles)
//  Max # of Sprites: 40
//  Max # of Sprites/line: 10
//  Clock speed: 4.194304 MHz

class EMULATOR {

    let mem : MEMORY
    let cpu : CPU
    
    var div_clocksum : Int = 0
    var timer_clocksum : Int = 0
    
    enum DEBUG_LEVEL {
        case ALL, ERROR
    }
    private static var output: String = "" {
        didSet {
            NotificationCenter.default.post(name: .consoleOutput, object: self.output)
        }
    }
    private static var DEBUG : DEBUG_LEVEL = .ERROR
    
    init() {
        EMULATOR.debugLog("gb.iOS starting up...", level: .ERROR)
        mem = MEMORY()
        cpu = CPU(mem: mem)
    }

    func iter() {
        
        while(true) {
            cpu.step()
            handleTimer(mem.cyclesRan())
            handleInterrupts()
        }
    }
    
    func handleInterrupts() {
        
        let interruptMask: UInt8 = (mem.read(addr: 0xFFFF) & mem.read(addr: 0xFF0F))
        
        //  UnHALT on interrupt
        if (interruptMask > 0) && cpu.regs.flags.HALT {
            cpu.regs.flags.HALT = false
        }
        
        //  Interrupts are enabled...
        if cpu.interrupts_enabled {
            
            //  Some interrupt is enabled and allowed
            if interruptMask > 0 {
                
                //  Interrupts handled by priority
                
                //  VBlank
                if (interruptMask & 0b001) > 0 {
                    mem.pushToStack(mem.PC)
                    mem.PC = 0x40
                    mem.write(addr: 0xFF0F, val: mem.read(addr: 0xFF0F) & 0b1111_1110)
                }
                
                //  LCD Stat
                if (interruptMask & 0b010) > 0 {
                    mem.pushToStack(mem.PC)
                    mem.PC = 0x48
                    mem.write(addr: 0xFF0F, val: mem.read(addr: 0xFF0F) & 0b1111_1101)
                }
                
                //  Timer
                if (interruptMask & 0b100) > 0 {
                    mem.pushToStack(mem.PC)
                    mem.PC = 0x50
                    mem.write(addr: 0xFF0F, val: mem.read(addr: 0xFF0F) & 0b1111_1011)
                }
                
                cpu.interrupts_enabled = false
            }
        }
    }
    
    func handleTimer(_ cycle: Int) {
        
        //  set divider
        div_clocksum += cycle
        if div_clocksum >= 256 {
            div_clocksum -= 256
            mem.write(addr: 0xFF04, val: mem.read(addr: 0xFF04) &+ 1)
        }
        
        //  check if timer is on
        if (mem.read(addr: 0xFF07) & 0b10) > 0 {
            
            //  increase helper counter
            timer_clocksum += cycle * 4
            
            //  set frequency
            var freq = 4096
            switch mem.read(addr: 0xFF07) & 0b11 {
            case 1: freq = 262144
            case 2: freq = 65536
            case 3: freq = 16384
            default: freq = 4096
            }
            
            //  increment timer according to frequency
            while timer_clocksum >= (4194304 / freq) {
                
                //  increase TIMA
                mem.write(addr: 0xFF05, val: mem.read(addr: 0xFF05) &+ 1)
                
                //  check TIMA for overflow
                if mem.read(addr: 0xFF05) == 0x00 {
                    
                    //  set timer interrupt req
                    mem.write(addr: 0xFF0F, val: mem.read(addr: 0xFF0F) | 0b100)
                    
                    //  reset timer to timer modulo
                    mem.write(addr: 0xFF05, val: mem.read(addr: 0xFF06))
                    
                    timer_clocksum -= (4194304 / freq)
                }
            }
        }
    }
    
    static func debugLog(_ msg: String, terminator: String = "\n", level: DEBUG_LEVEL = .ALL) {
        switch level {
        case .ALL:
            if DEBUG == .ALL {
                output += msg + terminator
            }
        case .ERROR:
            if DEBUG == .ERROR {
                output += msg + terminator
            }
        }
    }
    
}
