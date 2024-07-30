//
//  ChanelEntity+CoreDataProperties.swift
//  TeamChat
//
//  Created by Meenal Mishra on 30/07/24.
//
//

import Foundation
import CoreData


extension ChanelEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChanelEntity> {
        return NSFetchRequest<ChanelEntity>(entityName: "ChannelEntity")
    }

    @NSManaged public var groupFolderName: String?
    @NSManaged public var id: String?
    @NSManaged public var name: String?

}

extension ChanelEntity : Identifiable {

}
