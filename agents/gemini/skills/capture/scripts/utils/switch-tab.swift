#!/usr/bin/swift

import Foundation

/// 간단한 외부 명령 테스트 스크립트
/// 사용법: swift Tests/test_external_command.swift [탭번호]
/// 탭번호: 0=일반, 1=Snippets, 2=고급 (기본값: 1)

// 명령행 인수 처리
let arguments = CommandLine.arguments
var targetTab = 1  // 기본값: Snippets 탭

if arguments.count > 1 {
    if let tab = Int(arguments[1]), tab >= 0 && tab <= 4 {
        targetTab = tab
    } else {
        print("오류: 탭 번호는 0~4 사이의 정수여야 합니다. (0:일반, 1:Snippets, 2:Folders, 3:History, 4:Advanced)")
        exit(1)
    }
}

let tabNames = ["일반", "Snippets", "Folders", "History", "Advanced"]
print("fSnippet 외부 명령 테스트 - \(tabNames[targetTab]) 탭으로 이동")

// 1. 설정창 열기 및 탭 설정
print("📱 설정창 열기 명령 전송...")
let nc = DistributedNotificationCenter.default()
nc.postNotificationName(
    NSNotification.Name("fSnippetOpenSettings"), 
    object: nil, 
    userInfo: ["tab": targetTab], 
    options: .deliverImmediately
)

// 잠시 대기
usleep(2000000) // 2초

// 2. 추가 탭 변경 명령 (확실히 하기 위해)
print("🔄 탭 변경 명령 전송...")
nc.postNotificationName(
    NSNotification.Name("fSnippetChangeTab"), 
    object: nil, 
    userInfo: ["tabIndex": targetTab], 
    options: .deliverImmediately
)

print("✅ 외부 명령 전송 완료!")
print("앱에서 명령을 받으면 \(tabNames[targetTab]) 탭으로 설정창이 열릴 것입니다.")