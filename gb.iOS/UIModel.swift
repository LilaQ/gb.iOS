//
//  UIModel.swift
//  gb.iOS
//
//  Created by Jan on 15.01.22.
//

import Foundation
import UIKit

class UIModel: ObservableObject {
    @Published var output: String = "Moppelkotze"
    
    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(consoleOutput),
                                               name: .consoleOutput,
                                               object: nil
                                            )
    }
    
    @objc private func consoleOutput(_ notification: Notification) {
        guard let item = notification.object as? String else {
            print("Invalid notification object.")
            return
        }
        DispatchQueue.main.async {
            self.output = item
        }
    }
    
}
