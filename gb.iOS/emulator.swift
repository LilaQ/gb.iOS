//
//  main.swift
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

class EMULATOR {

    let mem : MEMORY
    let cpu : CPU
    
    init() {
        print("gb.iOS starting up...")
        mem = MEMORY()
        cpu = CPU(mem: mem)
        iter()
    }

    func iter() {
        
        while(true) {
            cpu.step()
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
    
    func handleTimer() {
        
    }
    
}
