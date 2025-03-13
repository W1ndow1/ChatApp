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
        
        // 시간 차이 계산
        let components = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: serverDate, to: now)
        
        // DateFormatter 설정 (필요할 때만 사용)
        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        
        // 1년 이상 차이
        if let months = components.month, months >= 12 {
            formatter.dateFormat = "yy년MM월dd일"
            return formatter.string(from: serverDate)
        }
        
        // 2일 이상 차이
        if let days = components.day, days > 1 {
            formatter.dateFormat = "M월dd일"
            return formatter.string(from: serverDate)
        }
        
        // 어제
        if let days = components.day, days == 1 {
            return "어제"
        }
        
        // 오늘 (24시간 이내)
        if let hours = components.hour, hours >= 1 {
            return "\(hours)시간 전"
        }
        
        // 1시간 이내
        if let minutes = components.minute, minutes >= 1 {
            return "\(minutes)분 전"
        }
        
        // 1분 미만
        return "방금 전"
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
