//
//  ContentView.swift
//  gb.iOS
//
//  Created by Jan on 06.01.22.
//

import SwiftUI

struct ContentView: View {
    
    let emulator: EMULATOR = EMULATOR()
    
    var body: some View {
        Text("Hello, world!")
            .padding()
            .onAppear {
                print("FUCK ARSE")
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
