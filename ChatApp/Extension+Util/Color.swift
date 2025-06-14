//
//  Color.swift
//  ChatApp
//
//  Created by window1 on 6/7/25.
//
import SwiftUI

extension Color {
    
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        
        var rgbValue: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgbValue) else {
            return nil
        }
        
        switch hexSanitized.count {
        case 6: // RGB (RRGGBB)
            let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = Double(rgbValue & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b)
        case 8: // ARGB (AARRGGBB)
            let a = Double((rgbValue & 0xFF000000) >> 24) / 255.0
            let r = Double((rgbValue & 0x00FF0000) >> 16) / 255.0
            let g = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
            let b = Double(rgbValue & 0x000000FF) / 255.0
            self.init(red: r, green: g, blue: b, opacity: a)
        default:
            return nil
        }
    }
    
    func toHexCode() -> String? {
        let uiColor = UIColor(self)
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        
        let a = Int(alpha * 255)
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02x%02x%02x%02x", a, r, g, b)
    }
}
