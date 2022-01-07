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
        }
        
    }
    
}
