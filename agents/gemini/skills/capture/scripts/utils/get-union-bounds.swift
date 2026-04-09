#!/usr/bin/swift

import Cocoa
import CoreGraphics

// Usage: swift get_union_bounds.swift "Title1" "Title2"

guard CommandLine.arguments.count > 2 else {
    print("ERROR: Usage: swift get_union_bounds.swift \"Title1\" \"Title2\"")
    exit(1)
}

let title1 = CommandLine.arguments[1]
let title2 = CommandLine.arguments[2]

func getWindowBounds(title: String) -> CGRect? {
    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    
    // Find window belonging to fSnippet with matching title
    // Priority: Specific Title Match
    for entry in windowList {
        guard let ownerName = entry[kCGWindowOwnerName as String] as? String,
              ownerName.contains("fSnippet") || ownerName == "Xcode", // Allow Xcode for testing
              let winTitle = entry[kCGWindowName as String] as? String,
              winTitle == title || winTitle.contains(title) else { continue }
            
        // Valid Window Found
        if let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
           let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
            
            // Filter out tiny windows (tooltips etc)
            if bounds.width > 50 && bounds.height > 50 {
                return bounds
            }
        }
    }
    return nil
}

let bounds1 = getWindowBounds(title: title1)
let bounds2 = getWindowBounds(title: title2)

var finalRect: CGRect = .zero

if let b1 = bounds1, let b2 = bounds2 {
    finalRect = b1.union(b2)
} else if let b1 = bounds1 {
    finalRect = b1
} else if let b2 = bounds2 {
    finalRect = b2
} else {
    print("ERROR: Neither window found")
    exit(1)
}

// Format: x,y,width,height
print("\(Int(finalRect.origin.x)),\(Int(finalRect.origin.y)),\(Int(finalRect.width)),\(Int(finalRect.height))")
