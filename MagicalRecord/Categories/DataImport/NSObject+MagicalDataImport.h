//
//  NSDictionary+MagicalDataImport.h
//  Magical Record
//
//  Created by Saul Mora on 9/4/11.
//  Copyright 2011 Magical Panda Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (MagicalRecord_DataImport)

- (NSString *)MR_lookupKeyWithMappedKey:(NSString *)key inUserInfo:(NSDictionary *)userInfo;

- (NSString *)MR_lookupKeyForAttribute:(NSPropertyDescription *)attributeInfo;
- (id)MR_valueForAttribute:(NSPropertyDescription *)attributeInfo;

- (NSString *)MR_lookupKeyForRelationship:(NSRelationshipDescription *)relationshipInfo;
- (id)MR_relatedValueForRelationship:(NSRelationshipDescription *)relationshipInfo;

- (id)MR_valueForPrimaryKeyAttribute:(NSAttributeDescription *)primaryKeyAttribute;

@end
