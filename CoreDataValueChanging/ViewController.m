//
//  ViewController.m
//  CoreDataValueChanging
//
//  Created by Sam Duke on 10/11/2014.
//  Copyright (c) 2014 samskiter. All rights reserved.
//

#import <CoreData/CoreData.h>

#import "ViewController.h"
#import "Entity.h"

@interface ViewController ()

@property (nonatomic, strong) NSManagedObjectModel * managedObjectModel;
@property (nonatomic, strong) NSPersistentStoreCoordinator * persistentStoreCoordinator;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSManagedObjectContext * uiCtx = [self contextForUIWork];
    NSEntityDescription * entityDesc = [NSEntityDescription entityForName:@"Entity" inManagedObjectContext:uiCtx];
    Entity * entity = [[Entity alloc] initWithEntity:entityDesc insertIntoManagedObjectContext:uiCtx];
    entity.testproperty = @(1);
    NSError * error = nil;
    [uiCtx save:&error];
    if (error)
    {
        assert(0);
    }

    NSManagedObjectID * objID = entity.objectID;
    [self doStuffToObjectWithIDOnAnotherThreadAndAnotherContext:objID];
    entity.testproperty = @(2);
    [uiCtx setMergePolicy:NSErrorMergePolicy];
    error = nil;
    [uiCtx save:&error];
    if (!error)
    {
        //Will we hit this?
        assert(0);
    }
}

-(void)doStuffToObjectWithIDOnAnotherThreadAndAnotherContext:(NSManagedObjectID*)objID
{
    dispatch_barrier_sync(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSManagedObjectContext * bgCtx = [self contextForBackgroundWork];
        Entity * bgEntity = (Entity*)[bgCtx objectWithID:objID];
        
        [bgCtx performBlockAndWait:^{
        
            //set to same value
            bgEntity.testproperty = bgEntity.testproperty;
            
            NSError * bgError = nil;
            [bgCtx save:&bgError];
            if (bgError)
            {
                assert(0);
            }
        }];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSManagedObjectContext*)contextForBackgroundWork
{
    NSManagedObjectContext * ctx;
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
    {
        ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [ctx performBlockAndWait:^{
            //merge policy will be changed on the fly anyway
            [ctx setMergePolicy:NSErrorMergePolicy];
            [ctx setPersistentStoreCoordinator:coordinator];
        }];
    }
    return ctx;
}

- (NSManagedObjectContext *)contextForUIWork
{
    assert([NSThread isMainThread]);
    NSManagedObjectContext * ctx;
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
    {
        ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [ctx performBlockAndWait:^{
            [ctx setMergePolicy:NSErrorMergePolicy];
            [ctx setPersistentStoreCoordinator:coordinator];
        }];
    }
    return ctx;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil)
    {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"CoreDataValueChanging" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}


- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator)
    {
        return _persistentStoreCoordinator;
    }
    
    NSURL *currStoreURL = [[self class] defaultStoreURL];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    NSDictionary *options =@{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES};
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:currStoreURL options:options error:&error]) {
        
        error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:currStoreURL error:&error]; // ignore error from this
        error = nil;
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:currStoreURL options:options error:&error])
        {
            // Show a crash!
            abort();
        }
    }
    
    return _persistentStoreCoordinator;
}

+(NSURL *)defaultStoreURL
{
    NSURL * applicationDocumentsDirectory =[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    return [applicationDocumentsDirectory URLByAppendingPathComponent:@"default.sqlite"];
}

@end
