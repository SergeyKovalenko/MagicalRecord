//
//  ImportAbstractEntitySpec.m
//  MagicalRecord
//
//  Created by Sergey Kovalenko on 2/28/14.
//  Copyright 2014 Magical Panda Software LLC. All rights reserved.
//

#import "Specta.h"

#define EXP_SHORTHAND

#import "Expecta.h"

#import "AbstractEntity.h"
#import "SubEntity.h"

SpecBegin(ImportSingleRelatedEntity)

describe(@"ImportSingleRelatedEntity", ^{
__block NSManagedObjectContext *managedObjectContext;
//    __block AbstractEntity    *abstractEntity;
//    __block SubEntity    *subentity;

beforeAll(^{
[
MagicalRecord setDefaultModelFromClass:
[
self class
]];
[
MagicalRecord setupCoreDataStackWithInMemoryStore
];

managedObjectContext = [NSManagedObjectContext MR_defaultContext];
});

afterAll(^{
[
MagicalRecord cleanUp
];
});

it(@"AbstractEntity description", ^{
NSEntityDescription *abstractEntity = [AbstractEntity MR_entityDescription];
NSEntityDescription *subentity = [SubEntity MR_entityDescription];

expect(abstractEntity)
.to.
beNil;
expect(subentity)
.toNot.
beNil;

});


});

SpecEnd
