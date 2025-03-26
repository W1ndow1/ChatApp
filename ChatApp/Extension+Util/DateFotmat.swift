//
//  Date.swift
//  ChatApp
//
//  Created by window1 on 3/12/25.
//

import Foundation
import Firebase

struct DateFormat {
    static func lastMessageTime(timeStamp: Timestamp) -> String {
        let serverDate = timeStamp.dateValue() // 서버 시간 (UTC)
        let now = Date() // 현재 시간
        
        // 한국 시간(KST)으로 변환을 위한 캘린더 설정
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    
        // DateFormatter 설정 (필요할 때만 사용)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        
        //오늘일 경우
        if calendar.isDateInToday(serverDate) {
            let components = calendar.dateComponents([.hour, .minute], from: serverDate, to: now)
            if let hours = components.hour, hours >= 1{
                formatter.dateFormat = "a h:mm"
                return formatter.string(from: serverDate)
            }
            if let minutes = components.minute, minutes >= 1 {
                return "\(minutes)분 전"
            }
            return "방금 전"
            
        }
        
        // 날짜가 어제인지 확인
        if calendar.isDateInYesterday(serverDate) {
            return "어제"
        }
        
        // 날짜가 오늘, 어제가 아닐 때
        let serverYear = calendar.component(.year, from: serverDate)
        let currentYear = calendar.component(.year, from: now)
        
        if serverYear != currentYear {
            formatter.dateFormat = "yy년 M월 dd일"
        } else {
            formatter.dateFormat = "M월 dd일"
        }
        return formatter.string(from: serverDate)
    }
}

extension Date {
    ///원하는 날짜 형식으로 변환
    ///yyyy-mm-dd hh:mm:ss
    func toString(dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = dateFormat
        return formatter.string(from: self)
    }
}
