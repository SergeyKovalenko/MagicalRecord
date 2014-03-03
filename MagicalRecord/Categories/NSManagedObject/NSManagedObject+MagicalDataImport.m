//
//  NSManagedObject+JSONHelpers.m
//
//  Created by Saul Mora on 6/28/11.
//  Copyright 2011 Magical Panda Software LLC. All rights reserved.
//

#import "CoreData+MagicalRecord.h"
#import "NSObject+MagicalDataImport.h"
#import <objc/runtime.h>

void MR_swapMethodsFromClass(Class c, SEL orig, SEL new);

NSString * const kMagicalRecordImportCustomDateFormatKey            = @"dateFormat";
NSString * const kMagicalRecordImportDefaultDateFormatString        = @"yyyy-MM-dd'T'HH:mm:ss'Z'";

NSString * const kMagicalRecordImportAttributeKeyMapKey             = @"mappedKeyName";
NSString * const kMagicalRecordImportAttributeValueClassNameKey     = @"attributeValueClassName";

NSString * const kMagicalRecordImportRelationshipMapKey             = @"mappedKeyName";
NSString * const kMagicalRecordImportRelationshipLinkedByKey        = @"relatedByAttribute";
NSString * const kMagicalRecordImportRelationshipTypeKey            = @"type";  //this needs to be revisited

NSString * const kMagicalRecordImportSubentityLinkedByKey           = @"subentitiesAttribute";
NSString * const kMagicalRecordImportSubentityClassMapKey           = @"mappedSubentityClassName";


NSString * const kMagicalRecordImportAttributeUseDefaultValueWhenNotPresent = @"useDefaultValueWhenNotPresent";

@interface NSObject (MagicalRecord_DataImportControls)

- (id) MR_valueForUndefinedKey:(NSString *)key;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

@implementation NSManagedObject (MagicalRecord_DataImport)

- (BOOL) MR_importValue:(id)value forKey:(NSString *)key
{
//    NSString *selectorString = [NSString stringWithFormat:@"import%@:", [key MR_capitalizedFirstCharacterString]];
//    SEL selector = NSSelectorFromString(selectorString);
//    if ([self respondsToSelector:selector])
//    {
//        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
//        [invocation setTarget:self];
//        [invocation setSelector:selector];
//        [invocation setArgument:&value atIndex:2];
//        [invocation invoke];
//
////        [self performSelector:selector withObject:value];
//
//        return YES;
//    }
    return NO;
}

- (void) MR_setAttributes:(NSDictionary *)attributes forKeysWithObject:(id)objectData
{    
    for (NSString *attributeName in attributes) 
    {
        NSAttributeDescription *attributeInfo = [attributes valueForKey:attributeName];
        NSString *lookupKeyPath = [objectData MR_lookupKeyForAttribute:attributeInfo];
        
        if (lookupKeyPath) 
        {
            id value = [attributeInfo MR_valueForKeyPath:lookupKeyPath fromObjectData:objectData];
            if (![self MR_importValue:value forKey:attributeName])
            {
                [self MR_setValueIfDifferent:value forKey:attributeName];
            }
        } 
        else 
        {
            if ([[[attributeInfo userInfo] objectForKey:kMagicalRecordImportAttributeUseDefaultValueWhenNotPresent] boolValue]) 
            {
                id value = [attributeInfo defaultValue];
                if (![self MR_importValue:value forKey:attributeName])
                {
                    [self MR_setValueIfDifferent:value forKey:attributeName];
                }
            }
        }
    }
}

- (void)MR_setValueIfDifferent:(id)value forKey:(NSString *)key
{
    id currentValue = [self valueForKey:key];
    if(currentValue == nil && value == nil)
    {
        return;
    }
    
    if((currentValue == nil && value != nil) || (currentValue != nil && value == nil))
    {
        [self setValue:value forKey:key];
        return;
    }
    if(![currentValue isEqual:value])
    {
        [self setValue:value forKey:key];
    }
}


- (NSManagedObject *) MR_findObjectForRelationship:(NSRelationshipDescription *)relationshipInfo withData:(id)singleRelatedObjectData
{
    NSEntityDescription *destinationEntity = [relationshipInfo destinationEntity];
    NSManagedObject *objectForRelationship = nil;

    id relatedValue;

    // if its a primitive class, than handle singleRelatedObjectData as the key for relationship
    if ([singleRelatedObjectData isKindOfClass:[NSString class]] ||
        [singleRelatedObjectData isKindOfClass:[NSNumber class]])
    {
        relatedValue = singleRelatedObjectData;
    }
    else if ([singleRelatedObjectData isKindOfClass:[NSDictionary class]])
	{
		relatedValue = [singleRelatedObjectData MR_relatedValueForRelationship:relationshipInfo];
	}
	else
    {
        relatedValue = singleRelatedObjectData;
    }

    if (relatedValue)
    {
        NSManagedObjectContext *context = [self managedObjectContext];
        Class managedObjectClass = NSClassFromString([destinationEntity managedObjectClassName]);
        NSString *primaryKey = [relationshipInfo MR_primaryKey];
        objectForRelationship = [managedObjectClass MR_findFirstByAttribute:primaryKey
																  withValue:relatedValue
																  inContext:context];
    }
	
    return objectForRelationship;
}

- (void) MR_addObject:(NSManagedObject *)relatedObject forRelationship:(NSRelationshipDescription *)relationshipInfo
{
    NSAssert2(relatedObject != nil, @"Cannot add nil to %@ for attribute %@", NSStringFromClass([self class]), [relationshipInfo name]);    
    NSAssert2([[relatedObject entity] isKindOfEntity:[relationshipInfo destinationEntity]], @"related object entity %@ not same as destination entity %@", [relatedObject entity], [relationshipInfo destinationEntity]);

    //add related object to set
    NSString *addRelationMessageFormat = @"set%@:";
    id relationshipSource = self;
    if ([relationshipInfo isToMany]) 
    {
        addRelationMessageFormat = @"add%@Object:";
        if ([relationshipInfo respondsToSelector:@selector(isOrdered)] && [relationshipInfo isOrdered])
        {
            //Need to get the ordered set
            NSString *selectorName = [[relationshipInfo name] stringByAppendingString:@"Set"];
            relationshipSource = [self performSelector:NSSelectorFromString(selectorName)];
            addRelationMessageFormat = @"addObject:";
        }
    }

    NSString *addRelatedObjectToSetMessage = [NSString stringWithFormat:addRelationMessageFormat, attributeNameFromString([relationshipInfo name])];
 
    SEL selector = NSSelectorFromString(addRelatedObjectToSetMessage);
    
    @try 
    {
        [relationshipSource performSelector:selector withObject:relatedObject];        
    }
    @catch (NSException *exception) 
    {
        MRLog(@"Adding object for relationship failed: %@\n", relationshipInfo);
        MRLog(@"relatedObject.entity %@", [relatedObject entity]);
        MRLog(@"relationshipInfo.destinationEntity %@", [relationshipInfo destinationEntity]);
        MRLog(@"Add Relationship Selector: %@", addRelatedObjectToSetMessage);   
        MRLog(@"perform selector error: %@", exception);
    }
}

- (void) MR_setRelationships:(NSDictionary *)relationships forKeysWithObject:(id)relationshipData withBlock:(void(^)(NSRelationshipDescription *,id))setRelationshipBlock
{
    for (NSString *relationshipName in relationships) 
    {
        if ([self MR_importValue:relationshipData forKey:relationshipName]) 
        {
            continue;
        }
        
        NSRelationshipDescription *relationshipInfo = [relationships valueForKey:relationshipName];
        
        id relatedObjectData = [relationshipData MR_valueForPrimaryKeyAttribute:relationshipInfo];
        
        if (relatedObjectData == nil || [relatedObjectData isEqual:[NSNull null]]) 
        {
            continue;
        }
        
        setRelationshipBlock(relationshipInfo, relatedObjectData);
    }
}

- (BOOL) MR_preImport:(id)objectData;
{
    if ([self respondsToSelector:@selector(shouldImport:)])
    {
        BOOL shouldImport = (BOOL)[self shouldImport:objectData];
        if (!shouldImport) 
        {
            return NO;
        }
    }   

    if ([self respondsToSelector:@selector(willImport:)])
    {
        [self willImport:objectData];
    }
//    MR_swapMethodsFromClass([objectData class], @selector(valueForUndefinedKey:), @selector(MR_valueForUndefinedKey:));
    return YES;
}

- (BOOL) MR_postImport:(id)objectData;
{
//    MR_swapMethodsFromClass([objectData class], @selector(valueForUndefinedKey:), @selector(MR_valueForUndefinedKey:));
    if ([self respondsToSelector:@selector(didImport:)])
    {
        [self performSelector:@selector(didImport:) withObject:objectData];
    }
    return YES;
}

- (BOOL) MR_performDataImportFromObject:(id)objectData relationshipBlock:(void(^)(NSRelationshipDescription*, id))relationshipBlock;
{
    BOOL didStartimporting = [self MR_preImport:objectData];
    if (!didStartimporting) return NO;
    
    NSDictionary *attributes = [[self entity] attributesByName];
    [self MR_setAttributes:attributes forKeysWithObject:objectData];
    
    NSDictionary *relationships = [[self entity] relationshipsByName];
    [self MR_setRelationships:relationships forKeysWithObject:objectData withBlock:relationshipBlock];
    
    return [self MR_postImport:objectData];  
}

- (BOOL) MR_importValuesForKeysWithObject:(id)objectData
{
	typeof(self) weakself = self;
    return [self MR_performDataImportFromObject:objectData
                              relationshipBlock:^(NSRelationshipDescription *relationshipInfo, id localObjectData) {
        
        SEL shouldImportSelector = NSSelectorFromString([NSString stringWithFormat:@"shouldImport%@:", [relationshipInfo.name MR_capitalizedFirstCharacterString]]);
        BOOL implementsShouldImport = (BOOL)[self respondsToSelector:shouldImportSelector];
       if(![relationshipInfo isToMany])
       {
           if (!(implementsShouldImport && !(BOOL)[self performSelector:shouldImportSelector withObject:localObjectData]))
           {
               NSManagedObject *relatedObject = [weakself MR_findObjectForRelationship:relationshipInfo withData:localObjectData];
                                      
               if (relatedObject == nil)
               {
                   NSEntityDescription *entityDescription = [relationshipInfo destinationEntity];
                   relatedObject = [entityDescription MR_createInstanceInContext:[weakself managedObjectContext]];
               }
               [relatedObject MR_importValuesForKeysWithObject:localObjectData];
               
               [weakself MR_setValueIfDifferent:relatedObject forKey:relationshipInfo.name];
           }
       }
       else
       {

           NSMutableArray *localObjectDataToImport = [NSMutableArray arrayWithCapacity:[localObjectData count]];
           for(id singleLocalObjectData in localObjectData)
           {
               if (!(implementsShouldImport && !(BOOL)[self performSelector:shouldImportSelector withObject:singleLocalObjectData]))
               {
                   [localObjectDataToImport addObject:singleLocalObjectData];
               }
           }
           
           if([localObjectDataToImport count] > 0)
           {
               id relatedObjects = [[weakself valueForKey:relationshipInfo.name] mutableCopy];
               
               NSString *primaryKeyName = [relationshipInfo MR_primaryKey];
               
               NSAttributeDescription *primaryKeyAttribute = [[relationshipInfo.destinationEntity attributesByName] valueForKey:primaryKeyName];
               NSArray *result = [NSClassFromString(relationshipInfo.destinationEntity.name) MR_importFromArray:localObjectData withPrimaryAttribute:primaryKeyAttribute inContext:[weakself managedObjectContext]];
               [relatedObjects addObjectsFromArray:result];
               
               
               [weakself MR_setValueIfDifferent:relatedObjects forKey:relationshipInfo.name];
           }
       }
    } ];
}

+ (id) MR_importFromObject:(id)objectData inContext:(NSManagedObjectContext *)context;
{
    NSEntityDescription *entity = [self MR_entityDescription];
    NSAttributeDescription *primaryAttribute = [entity MR_primaryAttributeToRelateBy];
    
    id value = [objectData MR_valueForAttribute:primaryAttribute];
    
    NSEntityDescription *importedEntity = [entity MR_importedEntityFromObject:objectData];
    id selfClass = NSClassFromString(importedEntity.managedObjectClassName);
    
    NSManagedObject *managedObject = [selfClass MR_findFirstByAttribute:[primaryAttribute name] withValue:value inContext:context];
    
    if (managedObject == nil) 
    {
        managedObject = [importedEntity MR_createInstanceInContext:context];
    }

    [managedObject MR_importValuesForKeysWithObject:objectData];

    return managedObject;
}

+ (id) MR_importFromObject:(id)objectData
{
    return [self MR_importFromObject:objectData inContext:[NSManagedObjectContext MR_defaultContext]];
}

+ (NSArray *) MR_importFromArray:(NSArray *)listOfObjectData
{
    return [self MR_importFromArray:listOfObjectData inContext:[NSManagedObjectContext MR_defaultContext]];
}

+ (NSArray *) MR_importFromArray:(NSArray *)listOfObjectData inContext:(NSManagedObjectContext *)context
{
    NSEntityDescription *entity = [self MR_entityDescription];
    NSAttributeDescription *primaryAttribute = [entity MR_primaryAttributeToRelateBy];
    return [self MR_importFromArray:listOfObjectData withPrimaryAttribute:primaryAttribute inContext:context];
}

+ (NSArray *) MR_importFromArray:(NSArray *)listOfObjectData withPrimaryAttribute:(NSAttributeDescription *)primaryAttribute inContext:(NSManagedObjectContext *)context
{
    NSMutableArray *resultObjects = [NSMutableArray arrayWithCapacity:listOfObjectData.count];
    
   

    NSPredicate *compoundPredicate = nil;
    NSEntityDescription *entity = [self MR_entityDescription];
    NSAttributeDescription *classTypeAttribute = [entity MR_subentityAttributeToInheritBy];
    
    NSPredicate *predicateTemplate = [NSPredicate predicateWithFormat:@"%K == $identifierValue AND $typeKey == $typeValue",primaryAttribute.name];

    for(id singleObjectData in listOfObjectData)
    {
        NSEntityDescription *importedEntity = [entity MR_importedEntityFromObject:singleObjectData];
        
        id primaryKeyValue = [singleObjectData MR_valueForPrimaryKeyAttribute:primaryAttribute];
        id typeyKeyValue = [singleObjectData MR_valueForAttribute:classTypeAttribute];

        if(primaryKeyValue && typeyKeyValue)
        {
            NSString *lookupTypeKey = [singleObjectData MR_lookupKeyForAttribute:classTypeAttribute];
            NSDictionary *variables = @{@"identifierValue" : primaryKeyValue,
                                        @"typeKey":lookupTypeKey,
                                        @"typeValue" : typeyKeyValue};
            
            NSPredicate *fulfilledPredicate = [predicateTemplate predicateWithSubstitutionVariables:variables];
            compoundPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:fulfilledPredicate, compoundPredicate, nil]];
        }
    }
    
    NSArray *fetchedObjects = [self MR_findAllWithPredicate:compoundPredicate inContext:context];
    
    NSMutableDictionary *objectCache = [[NSMutableDictionary alloc] initWithCapacity:fetchedObjects.count];
    
    for(NSManagedObject *object in fetchedObjects)
    {
        NSAttributeDescription *classTypeAttribute = [object.entity MR_subentityAttributeToInheritBy];
        NSString *key = [NSString stringWithFormat:@"%@.%@", [object valueForKey:classTypeAttribute.name], [object valueForKey:primaryAttribute.name]];
        [objectCache setObject:object forKey:key];
    }
    
    for(id singleObjectData in listOfObjectData)
    {
        NSEntityDescription *importedEntity = [entity MR_importedEntityFromObject:singleObjectData];
        
        id primaryKey = [singleObjectData MR_valueForAttribute:primaryAttribute];
        id typeyKeyValue = [singleObjectData MR_valueForPrimaryKeyAttribute:classTypeAttribute];
        
        NSString *key = [NSString stringWithFormat:@"%@.%@", typeyKeyValue, primaryKey];

        NSManagedObject *object = [objectCache objectForKey:key];
        
        if(object == nil)
        {
            object = [importedEntity MR_createInstanceInContext:context];
        }
        
        [object MR_importValuesForKeysWithObject:singleObjectData];
        [resultObjects addObject:object];
    }
    
    return resultObjects;
}

@end

#pragma clang diagnostic pop

void MR_swapMethodsFromClass(Class c, SEL orig, SEL new)
{
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if (class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
    {
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    }
    else
    {
        method_exchangeImplementations(origMethod, newMethod);
    }
}
