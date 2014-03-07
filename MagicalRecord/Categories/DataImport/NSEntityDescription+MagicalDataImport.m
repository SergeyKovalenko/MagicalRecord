//
//  NSEntityDescription+MagicalDataImport.m
//  Magical Record
//
//  Created by Saul Mora on 9/5/11.
//  Copyright 2011 Magical Panda Software LLC. All rights reserved.
//

#import "CoreData+MagicalRecord.h"

@implementation NSEntityDescription (MagicalRecord_DataImport)

- (NSAttributeDescription *)MR_primaryAttributeToRelateBy; {
    NSString *lookupKey = [[self userInfo] valueForKey:kMagicalRecordImportRelationshipLinkedByKey] ?:
            primaryKeyNameFromString([self name]);

    return [self MR_attributeDescriptionForName:lookupKey];
}

- (NSString *)MR_subentityImportTypeKey; {
    NSString *lookupKey = [[self userInfo] valueForKey:kMagicalRecordImportSubentityLinkedByKey] ?:
            subentityKeyNameFromString([self name]);
    return lookupKey;
}

- (NSString *)MR_subentityImportTypeValue; {
    return [[self userInfo] valueForKey:kMagicalRecordImportSubentityClassMapKey] ?: [self name];
}

- (id)MR_subentityTypeToInheritByFromObject:(id)importedObject {
    NSAssert(self.subentities.count, @"%@ entity should have subentities entity", self.name);
    NSDictionary *userInfo = [self userInfo];
    NSString *lookupKey = [self MR_subentityImportTypeKey];
    lookupKey = [importedObject MR_lookupKeyWithMappedKey:lookupKey inUserInfo:userInfo];

    return lookupKey != nil ? [importedObject valueForKeyPath:lookupKey] : nil;
}

- (NSDictionary *)MR_subentitiesByType {
    NSAssert(self.subentities.count, @"%@ entity should have subentities entity", self.name);
    NSString *type = [self MR_subentityImportTypeValue];
    NSMutableDictionary *subentitiesByType = [NSMutableDictionary dictionaryWithObject:self forKey:type];
    for (NSEntityDescription *subentity in self.subentities) {
        NSString *type = [subentity MR_subentityImportTypeValue];
        subentitiesByType[type] = subentity;
    }
    return [subentitiesByType copy];
}

- (NSEntityDescription *)MR_importedEntityFromObject:(id)objectData {
    if (self.subentities.count) {
        id type = [self MR_subentityTypeToInheritByFromObject:objectData];
        NSAssert(type, @"Can't fint subentity type for import");

        NSEntityDescription *entityForImport = [[self MR_subentitiesByType] objectForKey:type];
        NSAssert1(entityForImport, @"Can't fint entityForImport for key %@", type);
        return entityForImport;
    }
    return self;
}

- (NSManagedObject *)MR_createInstanceInContext:(NSManagedObjectContext *)context; {
    Class relatedClass = NSClassFromString([self managedObjectClassName]);
    NSManagedObject *newInstance = [relatedClass MR_createInContext:context];

    return newInstance;
}

- (NSAttributeDescription *)MR_attributeDescriptionForName:(NSString *)name; {
    __block NSAttributeDescription *attributeDescription;

    NSDictionary *attributesByName = [self attributesByName];

    if ([attributesByName count] == 0) {
        return nil;
    }

    [attributesByName enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key isEqualToString:name]) {
            attributeDescription = obj;

            *stop = YES;
        }
    }];

    return attributeDescription;
}

@end
