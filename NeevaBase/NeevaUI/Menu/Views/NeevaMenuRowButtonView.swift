//
//  NeevaMenuRowButtonView.swift
//  
//
//  Created by Stuart Allen on 13/03/21.
//  Copyright © 2021 Neeva. All rights reserved.
//
import SwiftUI

public struct NeevaMenuRowButtonView: View {
    
    let buttonName: String
    let buttonImage: String
    
    /// - Parameters:
    ///   - name: The display name of the button
    ///   - image: The string id of the button image
    public init(name: String, image: String){
        self.buttonName = name
        self.buttonImage = image
    }
    
    public var body: some View {
        Group{
            HStack{
                Text(buttonName)
                    .foregroundColor(Color(UIColor.theme.popupMenu.textColor))
                    .font(.system(size: NeevaUIConstants.menuFontSize))
                Spacer()
                Image(buttonImage)
                    .renderingMode(.template)
                    .foregroundColor(Color(UIColor.theme.popupMenu.buttonColor))
            }
        }
        .padding(NeevaUIConstants.menuRowPadding)
        .frame(minWidth: 0, maxWidth: NeevaUIConstants.menuMaxWidth)
        .background(Color(UIColor.theme.popupMenu.foreground))
        .cornerRadius(NeevaUIConstants.menuCornerDefault)
    }
}

struct NeevaMenuRowButtonView_Previews: PreviewProvider {
    static var previews: some View {
        NeevaMenuRowButtonView(name: "Test", image: "iphone")
    }
}
