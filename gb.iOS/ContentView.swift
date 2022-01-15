//
//  ContentView.swift
//  gb.iOS
//
//  Created by Jan on 06.01.22.
//

import SwiftUI

struct ContentView: View {
    
    let emulator: EMULATOR = EMULATOR()
    @ObservedObject var model: UIModel = UIModel()
    
    var body: some View {
        Text(model.output)
            .padding()
            .onAppear {
                DispatchQueue.global().async {
                    emulator.iter()
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
