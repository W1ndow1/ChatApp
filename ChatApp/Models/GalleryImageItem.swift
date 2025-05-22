//
//  GalleryImageItem.swift
//  ChatApp
//
//  Created by window1 on 5/22/25.
//
import FirebaseCore

struct GalleryImageItem: Identifiable {
    let id: String
    let url: String
    let userName: String
    let sendDate: Timestamp
}
