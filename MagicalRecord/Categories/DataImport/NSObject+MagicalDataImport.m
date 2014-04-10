//
//  NSDictionary+MagicalDataImport.m
//  Magical Record
//
//  Created by Saul Mora on 9/4/11.
//  Copyright 2011 Magical Panda Software LLC. All rights reserved.
//

#import "NSObject+MagicalDataImport.h"
#import "NSEntityDescription+MagicalDataImport.h"
#import "NSManagedObject+MagicalDataImport.h"
#import "CoreData+MagicalRecord.h"

NSUInteger const kMagicalRecordImportMaximumAttributeFailoverDepth = 10;

@implementation NSObject (MagicalRecord_DataImport)

//#warning If you implement valueForUndefinedKey: in any NSObject in your code, this may be the problem if something broke
- (id)MR_valueForUndefinedKey:(NSString *)key {
    return nil;
}

- (NSString *)MR_lookupKeyForAttribute:(NSPropertyDescription *)attributeInfo; {
    NSString *attributeName = [attributeInfo name];
    NSDictionary *userInfo = [attributeInfo userInfo];
    NSString *lookupKey = [userInfo valueForKey:kMagicalRecordImportAttributeKeyMapKey] ?: attributeName;
    return [self MR_lookupKeyWithMappedKey:lookupKey inUserInfo:userInfo];
}

- (NSString *)MR_lookupKeyWithMappedKey:(NSString *)key inUserInfo:(NSDictionary *)userInfo {
    id value = [self valueForKeyPath:key];

    for (NSUInteger i = 1; i < kMagicalRecordImportMaximumAttributeFailoverDepth && value == nil; i++) {
        NSString *attributeName = [NSString stringWithFormat:@"%@.%lu", kMagicalRecordImportAttributeKeyMapKey, (unsigned long) i];
        key = [userInfo valueForKey:attributeName];
        if (key == nil) {
            return nil;
        }
        value = [self valueForKeyPath:key];
    }

    return value != nil ? key : nil;
}

- (id)MR_valueForAttribute:(NSPropertyDescription *)attributeInfo {
    NSString *lookupKey = [self MR_lookupKeyForAttribute:attributeInfo];
    return lookupKey ? [self valueForKeyPath:lookupKey] : nil;
}

- (NSString *)MR_lookupKeyForRelationship:(NSRelationshipDescription *)relationshipInfo {
    NSEntityDescription *destinationEntity = [relationshipInfo destinationEntity];
    if (destinationEntity == nil) {
        MRLog(@"Unable to find entity for type '%@'", [self valueForKey:kMagicalRecordImportRelationshipTypeKey]);
        return nil;
    }

    NSString *primaryKeyName = [relationshipInfo MR_primaryKey];
    NSAttributeDescription *primaryKeyAttribute = [destinationEntity MR_attributeDescriptionForName:primaryKeyName];
    return [self MR_lookupKeyForAttribute:primaryKeyAttribute];
}

- (id)MR_valueForPrimaryKeyAttribute:(NSAttributeDescription *)primaryKeyAttribute {
    NSString *lookupKey = [self MR_lookupKeyForAttribute:primaryKeyAttribute];
    return lookupKey ? [self valueForKeyPath:lookupKey] : nil;
}

- (id)MR_relatedValueForRelationship:(NSRelationshipDescription *)relationshipInfo {
    NSString *lookupKey = [self MR_lookupKeyForRelationship:relationshipInfo];
    return lookupKey ? [self valueForKeyPath:lookupKey] : nil;
}

@end
