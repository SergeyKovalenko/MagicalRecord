//
//  NSEntityDescription+MagicalDataImport.m
//  Magical Record
//
//  Created by Saul Mora on 9/5/11.
//  Copyright 2011 Magical Panda Software LLC. All rights reserved.
//

#import "CoreData+MagicalRecord.h"
#import "NSEntityDescription+MagicalDataImport.h"

@implementation NSEntityDescription (MagicalRecord_DataImport)

- (NSAttributeDescription *) MR_primaryAttributeToRelateBy;
{
    NSString *lookupKey = [[self userInfo] valueForKey:kMagicalRecordImportRelationshipLinkedByKey] ?: primaryKeyNameFromString([self name]);

    return [self MR_attributeDescriptionForName:lookupKey];
}

- (NSAttributeDescription *) MR_subentityAttributeToInheritBy;
{
    NSAssert(self.isAbstract , @"%@ entity should be an abstract entity",self.name);
    NSString *lookupKey = [[self userInfo] valueForKey:kMagicalRecordImportSubentityLinkedByKey] ?: subentityKeyNameFromString([self name]);
    
    return [self MR_attributeDescriptionForName:lookupKey];
}

- (NSDictionary *) MR_subentitisByType;
{
    NSAssert(self.isAbstract, @"%@ entity should be an abstract entity",self.name);
    NSMutableDictionary *classNamesByType = [NSMutableDictionary dictionary];
    for (NSEntityDescription *subentity in self.subentities) {
        NSString *type = [[subentity userInfo] valueForKey:kMagicalRecordImportSubentityClassMapKey] ?: [self name];
        classNamesByType[type] = subentity;
    }
    return [classNamesByType copy];
}

- (NSEntityDescription *)MR_importedEntityFromObject:(id)objectData {
    if (self.isAbstract) {
        NSAttributeDescription *subentityAttribute = [self MR_subentityAttributeToInheritBy];
        NSAssert(subentityAttribute, @"Can't fint subentityAttribute for import");
        
        NSString *subentityClassType = [objectData MR_valueForAttribute:subentityAttribute];
        NSEntityDescription *entityForImport = [[self MR_subentitisByType] objectForKey:subentityClassType];
        NSAssert(entityForImport, @"Can't fint entityForImport for key %@", subentityClassType);
        return entityForImport;
    }
    return self;
}

- (NSManagedObject *) MR_createInstanceInContext:(NSManagedObjectContext *)context;
{
    Class relatedClass = NSClassFromString([self managedObjectClassName]);
    NSManagedObject *newInstance = [relatedClass MR_createInContext:context];
   
    return newInstance;
}

- (NSAttributeDescription *) MR_attributeDescriptionForName:(NSString *)name;
{
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
