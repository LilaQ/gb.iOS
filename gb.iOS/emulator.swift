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
            if cpu.interrupts_enabled {
                //  VBlank interrupt
                if ((mem.read(addr: 0xFFFF) & 1) & (mem.read(addr: 0xFF0F) & 1)) > 0 {
                    print("VBlank")
                    cpu.push(mem.PC, "VBlank interrupt, pushing PC to stack")
                    mem.PC = 0x40
                    mem.write(addr: 0xFF0F, val: mem.read(addr: 0xFF0F) & 0b1111_1110)  //  clear interrupt
                }
                cpu.interrupts_enabled = false
            }
        }
        
    }
    
}
