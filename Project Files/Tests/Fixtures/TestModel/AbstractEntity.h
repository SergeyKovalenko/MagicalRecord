//
//  AbstractEntity.h
//  Specta
//
//  Created by Sergey Kovalenko on 2/28/14.
//  Copyright (c) 2014 Peter Jihoon Kim. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface AbstractEntity : NSManagedObject

@property (nonatomic, retain) NSString *abstractAttribute;

@end
