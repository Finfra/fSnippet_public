#!/usr/bin/swift

import Foundation
import Cocoa

print("📱 팝업 표시 명령 전송 (Notification)...")
let nc = DistributedNotificationCenter.default()
nc.postNotificationName(
    NSNotification.Name("fSnippetShowPopup"), 
    object: nil, 
    userInfo: nil, 
    options: .deliverImmediately
)
print("✅ 명령 전송 완료")
