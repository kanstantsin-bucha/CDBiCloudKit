

#import "CDBCloudStore.h"
#import <CDBUUID/CDBUUID.h>


#define CDB_Store_Ubiqutos_URL_Postfix @".CDB.CDBCloudStore.store.ubiquitos.URL=NSURL"
#define CDB_Store_Current_State_Postfix @".CDB.CDBCloudStore.store.current.state=CDBCloudStoreState"
#define CDB_Store_SQLite_Files_Postfixes @[@"-shm", @"-wal"]
#define CDB_Store_Ubiquitos_Content_Local_Directory_Name @"CoreDataUbiquitySupport"


NSString * _Nonnull CDBCloudStoreWillChangeNotification = @"CDBCloudStoreWillChangeNotification";
NSString * _Nonnull CDBCloudStoreDidChangeNotification = @"CDBCloudStoreDidChangeNotification";


@interface CDBCloudStore ()



@property (strong, nonatomic, readwrite) NSURL * modelURL;
@property (strong, nonatomic, readwrite) NSString * name;
@property (strong, nonatomic, readwrite) NSManagedObjectModel * model;

@property (assign, nonatomic, readwrite) BOOL localStoreDisabled;
@property (strong, nonatomic, readwrite) NSManagedObjectContext * localContext;
@property (strong, nonatomic, readwrite) NSPersistentStore * localStore;
@property (strong, nonatomic) NSURL * localStoreURL;
@property (strong, nonatomic, readwrite) NSPersistentStoreCoordinator * localStoreCoordinator;

@property (assign, nonatomic, readwrite) BOOL ubiquitosStoreDisabled;
@property (strong, nonatomic, readwrite) NSManagedObjectContext * ubiquitosContext;
@property (strong, nonatomic, readwrite) NSPersistentStore * ubiqutosStore;
@property (strong, nonatomic) NSURL * ubiquitosStoreURL;
@property (strong, nonatomic, readwrite) NSURL * ubiquitosTempStoreURL;
@property (strong, nonatomic, readwrite) NSPersistentStoreCoordinator * ubiquitosStoreCoordinator;

@end


BOOL CDBCheckStoreState(CDBCloudStoreState state, NSUInteger option) {
    BOOL result = (state & option) > 0;
    return result;
}

CDBCloudStoreState CDBAddStoreState(CDBCloudStoreState state, NSUInteger option) {
    CDBCloudStoreState result = state | option;
    return result;
}

CDBCloudStoreState CDBRemoveStoreState(CDBCloudStoreState state, NSUInteger option) {
    CDBCloudStoreState result = state & ~option;
    return result;
}


@implementation CDBCloudStore

@synthesize state = _state;


#pragma mark - property -

- (BOOL)ubiquitous {
    BOOL result = CDBCheckStoreState(self.state, CDBCloudStoreUbiquitosActive);
    return result;
}

- (NSManagedObjectContext *)currentContext {
    NSManagedObjectContext * result = nil;
    
    if (self.ubiquitous) {
        result = self.ubiquitosContext;
    } else {
        result = self.localContext;
    }
    
    return result;
}

#pragma mark lazy loading

#pragma mark context

- (NSManagedObjectContext *)localContext {
    if (self.localStoreDisabled) {
        return nil;
    }
    
    if (_localContext == nil
        && self.localStoreCoordinator != nil) {
        _localContext =
            [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_localContext setPersistentStoreCoordinator:self.localStoreCoordinator];
    }
    return _localContext;
}

- (NSManagedObjectContext *)ubiquitosContext {
    if (self.ubiquitosStoreDisabled) {
        return nil;
    }
    
    if (_ubiquitosContext == nil
        && self.ubiquitosStoreCoordinator != nil) {
        _ubiquitosContext =
            [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_ubiquitosContext setPersistentStoreCoordinator:self.ubiquitosStoreCoordinator];
    }
    return _ubiquitosContext;
}

#pragma mark store options

- (NSDictionary *)localStoreOptions {
    if (_localStoreOptions == nil) {
        _localStoreOptions =  @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                NSInferMappingModelAutomaticallyOption: @YES,
                               };
    }
    return _localStoreOptions;
}

- (NSDictionary *)ubiquitosStoreOptions {
    if (_ubiquitosStoreOptions == nil && self.name != nil) {
        _ubiquitosStoreOptions =  @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                    NSInferMappingModelAutomaticallyOption: @YES,
                                    NSPersistentStoreUbiquitousContentNameKey: self.name,
                                   };
    }
    return _ubiquitosStoreOptions;
}

#pragma mark store coordinator

- (NSPersistentStoreCoordinator *)localStoreCoordinator {
    if (_localStoreCoordinator == nil
        && self.name != nil
        && self.model != nil) {
        NSPersistentStoreCoordinator * storeCoordinator = [self defaultStoreCoordinator];
        
        NSError * error = nil;
        NSPersistentStore * store =
            [storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                           configuration:nil
                                                     URL:self.localStoreURL
                                                 options:self.localStoreOptions
                                                   error:&error];
        if (error == nil) {
            _localStoreCoordinator = storeCoordinator;
            _localStore = store;
//            [self notifyDelegateThatCoreDataStackCreatedForUbiquitos:NO];
        }
    }
    
    return _localStoreCoordinator;
}

- (NSPersistentStoreCoordinator *)ubiquitosStoreCoordinator {
    if (_ubiquitosStoreCoordinator == nil
        && self.name != nil
        && self.model != nil) {
        NSPersistentStoreCoordinator * storeCoordinator = [self defaultStoreCoordinator];
        
        NSError * error = nil;
        NSPersistentStore * store =
        [storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                       configuration:nil
                                                 URL:self.ubiquitosTempStoreURL
                                             options:self.ubiquitosStoreOptions
                                               error:&error];
        if (error == nil) {
            _ubiquitosStoreCoordinator = storeCoordinator;
            _ubiqutosStore = store;
            [self subscribeToUbiquitosStoreNotifications];
//              [self notifyDelegateThatCoreDataStackCreatedForUbiquitos:YES];
        }
    }
    
    return _ubiquitosStoreCoordinator;
}

- (NSManagedObjectModel *)model {
    if (_model == nil
        && self.modelURL != nil) {
        _model = [[NSManagedObjectModel alloc] initWithContentsOfURL:self.modelURL];
    }
    
    return _model;
}

#pragma mark urls

- (NSURL *)localStoreURL {
    NSURL * result = [[self applicationDirectoryURLForPath:NSDocumentDirectory] URLByAppendingPathComponent:self.name];
    return result;
}

- (NSURL *)ubiquitosStoreURL {
    NSURL * result = [self loadUbiquitosStoreURLUsingName:self.name];
    return result;
}

- (NSURL *)ubiquitosTempStoreURL {
    NSURL * result = [[self applicationDirectoryURLForPath:NSLibraryDirectory] URLByAppendingPathComponent:self.name];;
    return result;
}

#pragma mark - life cycle -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - notifications -

- (void)subscribeToUbiquitosStoreNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(storesWillChange:)
                                                 name:NSPersistentStoreCoordinatorStoresWillChangeNotification
                                               object:self.ubiquitosStoreCoordinator];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(storesDidChange:)
                                                 name:NSPersistentStoreCoordinatorStoresDidChangeNotification
                                               object:self.ubiquitosStoreCoordinator];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(persistentStoreDidImportUbiquitousContentChanges:)
                                                 name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                               object:self.ubiquitosStoreCoordinator];
}

- (void)unsubscribeFromUbiquitosStoreNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)postNotificationUsingName:(NSString *)name {
    [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                        object:self];
}

#pragma mark - public -

- (void)initiateWithName:(NSString * _Nonnull)name
                modelURL:(NSURL * _Nonnull)modelURL {
    self.modelURL = modelURL;
    self.name = name;
    
    
    [self postNotificationUsingName:CDBCloudStoreWillChangeNotification];
}

- (void)updateForUbiquityActive:(BOOL)active
     usingSameUbiquityContainer:(BOOL)sameUbiquityContainer
                        withURL:(NSURL *)containerURL {
    if (self.name.length == 0) {
        [self changeStateTo:0];
        return;
    }
    
    CDBCloudStoreState state = [self loadCurrentStoreStateUsingName:self.name];
    
    if (sameUbiquityContainer == NO) {
        state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosInitiated);
        state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosActive);
    } else {
        state = CDBAddStoreState(state, CDBCloudStoreUbiquitosInitiated);
    }
    
    if (active) {
        state = CDBAddStoreState(state, CDBCloudStoreUbiquitosAvailable);
    } else {
        state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosAvailable);
        state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosActive);
    }
    
    [self changeStateTo:state];
}

- (void)replaceLocalStoreUsingUbiquitosOneWithCompletion:(CDBErrorCompletion _Nullable)completion {
    [self dismissAndDisableLocalCoreDataStack];
    
    [self removeCoreDataStoreAtURL:self.localStoreURL
                        completion:^(NSError * _Nullable deletionError) {
        NSMutableDictionary * migrationOptions = [self.localStoreOptions mutableCopy];
        migrationOptions[NSPersistentStoreRemoveUbiquitousMetadataOption] = @YES;

        NSError * error = nil;
        [self.ubiquitosStoreCoordinator migratePersistentStore:self.ubiqutosStore
                                                         toURL:self.localStoreURL
                                                       options:migrationOptions
                                                      withType:NSSQLiteStoreType
                                                         error:&error];
        [self enableLocalCoreDataStack];
        if (completion != nil) {
            completion(error);
        }
    }];
}

- (void)dismissAndDisableLocalCoreDataStack {
    [_localContext performBlockAndWait:^{
        [_localContext save:nil];
    }];
    
    self.localStoreDisabled = YES;

    _localContext = nil;
    _localStore = nil;
    _localStoreCoordinator = nil;
}

- (void)enableLocalCoreDataStack {
    self.localStoreDisabled = NO;
}

- (void)dismissAndDisableUbiquitosCoreDataStack {
    [_ubiquitosContext performBlockAndWait:^{
        [_ubiquitosContext save:nil];
    }];

    self.ubiquitosStoreDisabled = YES;
    
    [self unsubscribeFromUbiquitosStoreNotifications];
    
    _ubiquitosContext = nil;
    _ubiqutosStore = nil;
    _ubiquitosStoreCoordinator = nil;
}

- (void)enableUbiquitosCoreDataStack {
    self.ubiquitosStoreDisabled = NO;
    [self initiateUbiquitosConnection];
}

- (void)mergeUbiquitousContentChanges:(NSNotification *)changeNotification
                         usingContext:(NSManagedObjectContext *)context {
    if (context == nil) {
        return;
    }
    
    [context performBlock:^{
        [context mergeChangesFromContextDidSaveNotification:changeNotification];
    }];
    
    [self saveContext:context];
}

- (void)rebuildUbiquitosStoreFromUbiquitousContenWithCompletion:(CDBErrorCompletion _Nullable)completion {
    NSDictionary * options = self.ubiquitosStoreOptions;
    
    [self dismissAndDisableUbiquitosCoreDataStack];
    
    NSMutableDictionary * rebuildOptions = [options mutableCopy];
    rebuildOptions[NSPersistentStoreRebuildFromUbiquitousContentOption] = @(YES);
    self.ubiquitosStoreOptions = [rebuildOptions copy];
    
    [self enableUbiquitosCoreDataStack];
    [self touch:self.ubiquitosStoreCoordinator];
    
    self.ubiquitosStoreOptions = options;
    
    if (completion != nil) {
        completion(nil);
    }
}

- (void)removeLocalUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion {
    
    NSURL * firstPossibleDirectory =
        [[self applicationDirectoryURLForPath:NSDocumentDirectory]
            URLByAppendingPathComponent:CDB_Store_Ubiquitos_Content_Local_Directory_Name
                            isDirectory:YES];
    NSURL * secondPossibleDirectory =
        [[self applicationDirectoryURLForPath:NSLibraryDirectory]
            URLByAppendingPathComponent:CDB_Store_Ubiquitos_Content_Local_Directory_Name
                            isDirectory:YES];
    
    [self dismissAndDisableUbiquitosCoreDataStack];
    
    [self coordinatedRemoveItemsAtURLs:@[firstPossibleDirectory, secondPossibleDirectory]
                            completion:^(NSError * _Nullable error) {
        [self enableUbiquitosCoreDataStack];
        
        if (completion != nil) {
            completion(error);
        }
    }];
}

- (void)removeAllUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion {
    [self dismissAndDisableLocalCoreDataStack];
    [self dismissAndDisableUbiquitosCoreDataStack];
    
    NSError * error = nil;
    
    [NSPersistentStoreCoordinator removeUbiquitousContentAndPersistentStoreAtURL:self.ubiquitosStoreURL
                                                                         options:self.ubiquitosStoreOptions
                                                                           error:&error];
    
    if (error != nil) {
        DLogCDB(@"failed with error %@", error);
    }
    
    [self enableUbiquitosCoreDataStack];
    [self enableLocalCoreDataStack];
    
    if (completion != nil) {
        completion(error);
    }
}

- (void)removeAllUbiquitousStoreDataWithCompletion:(CDBErrorCompletion _Nullable)completion {
    
    NSError * error = nil;
    for (NSEntityDescription * entity in self.model.entities) {
        @autoreleasepool {
            [CDBCloudStore performRemovingAllObjectsForEntity:entity
                                                 usingContext:self.ubiquitosContext
                                                    batchSize:1000
                                                        error:&error];
            if (error != nil) {
                RLogCDB(YES, @"removing duplicates for entity %@ failed with %@", entity.name, error);
            }
        }
    }
    
    [self saveContext:self.ubiquitosContext];
    
    if (completion != nil) {
        completion(error);
    }
}

- (void)removeCoreDataStoreAtURL:(NSURL *)URL
                      completion:(CDBErrorCompletion)completion {
    if (URL.path.length == 0) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }
    
    NSMutableArray * URLsToRemove = [NSMutableArray array];
    [URLsToRemove addObject:URL];
    
    NSString * name = URL.lastPathComponent;
    NSURL * containingDirectoryURL = [URL URLByDeletingLastPathComponent];
    
    for (NSString * postfix in CDB_Store_SQLite_Files_Postfixes) {
        NSString * fileName = [name stringByAppendingString:postfix];
        NSURL * URLToDelete = [containingDirectoryURL URLByAppendingPathComponent:fileName];
        if (URLToDelete == nil) {
            continue;
        }
        [URLsToRemove addObject:URLToDelete];
    }
    
    [self coordinatedRemoveItemsAtURLs:URLsToRemove
                            completion:completion];
}

#pragma mark - private -

#pragma mark store state changing

- (void)changeStateTo:(CDBCloudStoreState)incomingState {
    if (self.state == incomingState) {
        return;
    }
    
    BOOL shouldPostDidChangeNotification = NO;

    if (CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosAvailable)
        && CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosInitiated)) {
        incomingState = CDBAddStoreState(incomingState, CDBCloudStoreUbiquitosActive);
    }
    
    if (CDBCheckStoreState(self.state, CDBCloudStoreUbiquitosActive)
        && (CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosActive) == NO)) {
        [self postNotificationUsingName:CDBCloudStoreWillChangeNotification];
        
        [self notifyDelegateThatStoreSwitchingToLocal];
        
        shouldPostDidChangeNotification = YES;
    }
    
    if ((CDBCheckStoreState(self.state, CDBCloudStoreUbiquitosActive) == NO)
        && CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosActive)) {
        [self postNotificationUsingName:CDBCloudStoreWillChangeNotification];
        
        [self touch:self.ubiquitosStoreCoordinator];
        
        [self storeSystemProvidedUbiquitosStoreData];
        
        [self notifyDelegateThatStoreSwitchingToUbiquitous];
        
        shouldPostDidChangeNotification = YES;
    }
    
    if (CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosAvailable)
        && CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosInitiated) == NO) {
        [self initiateUbiquitosConnection];
    }

    _state = incomingState;
    [self saveCurrentState:_state
                 usingName:self.name];
    
    if (shouldPostDidChangeNotification) {
        __weak typeof (self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [wself postNotificationUsingName:CDBCloudStoreDidChangeNotification];
        });
    }
    
    [self notifyDelegateThatStoreDidChangeState];
}

- (void)initiateUbiquitosConnection {
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wself touch:self.ubiquitosStoreCoordinator];
    });
}

#pragma mark delegate method calls

- (void)notifyDelegateThatStoreSwitchingToUbiquitous {
    if ([self.delegate respondsToSelector:@selector(ubiquitousActivationBeginAtCDBCloudStore:)]) {
        [self.delegate ubiquitousActivationBeginAtCDBCloudStore:self];
    }
}

- (void)notifyDelegateThatStoreSwitchingToLocal {
    if ([self.delegate respondsToSelector:@selector(localActivationBeginAtCDBCloudStore:)]) {
        [self.delegate localActivationBeginAtCDBCloudStore:self];
    }
}

- (void)notifyDelegateThatStoreDidChangeState {
    if ([self.delegate respondsToSelector:@selector(didChangeStateOfCDBCloudStore:)]) {
        [self.delegate didChangeStateOfCDBCloudStore:self];
    }
}

- (void)notifyDelegateThatUserWillRemoveContentOfStore {
    if ([self.delegate respondsToSelector:@selector(didDetectThatUserWillRemoveContentOfCDBCloudStore:)]) {
        [self.delegate didDetectThatUserWillRemoveContentOfCDBCloudStore:self];
    }
}

//- (void)notifyDelegateThatCoreDataStackCreatedForUbiquitos:(BOOL)ubiquitos {
//    if ([self.delegate respondsToSelector:@selector(CDBCloudStore:didCreateCoreDataStackThatUbiquitous:)]) {
//        [self.delegate CDBCloudStore:self didCreateCoreDataStackThatUbiquitous:ubiquitos];
//    }
//}

#pragma mark context 

- (void)saveContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        NSError * error = nil;
        
        if ([context hasChanges]) {
            [context save:&error];
            
            if (error != nil) {
                // perform error handling
                NSLog(@"%@", [error localizedDescription]);
            }
        }
    }];
}

- (void)resetContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        [context reset];
    }];
}

#pragma mark iCloud store changes handling

- (void)persistentStoreDidImportUbiquitousContentChanges:(NSNotification *)changeNotification {
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([wself.delegate respondsToSelector:@selector(CDBCloudStore:didImportUbiquitousContentChanges:)]) {
            [wself.delegate CDBCloudStore:wself
        didImportUbiquitousContentChanges:changeNotification];
        } else {
            [wself mergeUbiquitousContentChanges:changeNotification
                                    usingContext:wself.ubiquitosContext];
        }
        
        [wself postNotificationUsingName:CDBCloudStoreDidChangeNotification];
    });
}

- (void)storesWillChange:(NSNotification *)notification {
    if ([NSThread isMainThread]) {
        [self handleStoresWillChange:notification];
        return;
    }
    __weak typeof (self) wself = self;
    dispatch_sync(dispatch_get_main_queue(), ^{
        [wself handleStoresWillChange:notification];
    });
}

- (void)handleStoresWillChange:(NSNotification *)notification {
    
    NSPersistentStoreUbiquitousTransitionType transitionType =
        [self transitionTypeFromNotification:notification];
    
    CDBCloudStoreState state = self.state;
    switch (transitionType) {
        case NSPersistentStoreUbiquitousTransitionTypeAccountAdded: {
        }   break;
        
        case NSPersistentStoreUbiquitousTransitionTypeAccountRemoved: {
            state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosActive);
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeContentRemoved: {
            [self notifyDelegateThatUserWillRemoveContentOfStore];
            state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosAvailable);
            state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosActive);
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeInitialImportCompleted: {
        }   break;
            
        default:
            break;
    }
    
    [self changeStateTo:state];
    
    [self saveContext:self.currentContext];
    [self resetContext:self.currentContext];
}

- (void)storesDidChange:(NSNotification *)notification {
    if ([NSThread isMainThread]) {
        [self handleStoresDidChange:notification];
        return;
    }
    __weak typeof (self) wself = self;
    dispatch_sync(dispatch_get_main_queue(), ^{
        [wself handleStoresDidChange:notification];
    });
}

- (void)handleStoresDidChange:(NSNotification *)notification {
    NSPersistentStoreUbiquitousTransitionType transitionType =
        [self transitionTypeFromNotification:notification];
    
    CDBCloudStoreState state = self.state;
    switch (transitionType) {
        case NSPersistentStoreUbiquitousTransitionTypeAccountAdded: {
        }   break;
        
        case NSPersistentStoreUbiquitousTransitionTypeAccountRemoved: {
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeContentRemoved: {
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeInitialImportCompleted: {
            state = CDBAddStoreState(state, CDBCloudStoreUbiquitosInitiated);
        }   break;
            
        default:
            break;
    }
    
    [self changeStateTo:state];
}

- (NSPersistentStoreUbiquitousTransitionType)transitionTypeFromNotification:(NSNotification *)notification {
    NSNumber * transition = notification.userInfo[@"NSPersistentStoreUbiquitousTransitionTypeKey"];
    NSPersistentStoreUbiquitousTransitionType result =
        (NSPersistentStoreUbiquitousTransitionType)transition.unsignedIntegerValue;
    return result;
}

#pragma mark directory urls

- (NSURL *)applicationDirectoryURLForPath:(NSSearchPathDirectory)pathDirectory {
    NSURL * result =
        [[[NSFileManager defaultManager] URLsForDirectory:pathDirectory inDomains:NSUserDomainMask] lastObject];
    return result;
}

#pragma mark store to user defaults 

#pragma mark CDB.CDBCloudStore.store.ubiquitos.URL=NSURL

- (NSString *)ubiquitosStoreURLKeyUsingName:(NSString *)name {
    NSString * result = [name stringByAppendingString:CDB_Store_Ubiqutos_URL_Postfix];
    return result;
}

- (void)saveUbiquitosStoreURL:(NSURL *)storeURL
                    usingName:(NSString *)name {
    if (name.length == 0
        || storeURL == nil) {
        return;
    }
    
    NSString * key = [self ubiquitosStoreURLKeyUsingName:name];
    
    [[NSUserDefaults standardUserDefaults] setURL:storeURL
                                           forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSURL *)loadUbiquitosStoreURLUsingName:(NSString *)name {
    NSString * key = [self ubiquitosStoreURLKeyUsingName:name];
    
    NSURL * result = [[NSUserDefaults standardUserDefaults] URLForKey:key];
    return result;
}

#pragma mark CDB.CDBCloudStore.store.current.state=CDBCloudStoreState

- (NSString *)currentStoreTypeKeyUsingName:(NSString *)name {
    NSString * result = [name stringByAppendingString:CDB_Store_Current_State_Postfix];
    return result;
}

- (void)saveCurrentState:(CDBCloudStoreState)storeState
               usingName:(NSString *)name {
    if (name.length == 0) {
        return;
    }
    
    NSString * key = [self currentStoreTypeKeyUsingName:name];
    
    [[NSUserDefaults standardUserDefaults] setInteger:storeState
                                               forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (CDBCloudStoreState)loadCurrentStoreStateUsingName:(NSString *)name {
    NSString * key = [self currentStoreTypeKeyUsingName:name];
    
    CDBCloudStoreState result = (CDBCloudStoreState)[[NSUserDefaults standardUserDefaults] integerForKey:key];
    return result;
}


#pragma mark ubiquitos url store

- (void)storeSystemProvidedUbiquitosStoreData {
    NSURL * URL = self.ubiqutosStore.URL;
    DLogCDB(@"Ubiquios store URL %@", URL);
    [self saveUbiquitosStoreURL:URL
                      usingName:self.name];
}

#pragma mark store coordinator

- (NSPersistentStoreCoordinator *)defaultStoreCoordinator {
    if (self.model == nil) {
        return nil;
    }
    
    NSPersistentStoreCoordinator * result =
        [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.model];
    return result;
}

#pragma mark touch

- (void)touch:(NSObject *)object {
    [object isKindOfClass:[object class]];
}



#pragma mark - files

- (void)coordinatedRemoveItemAtURL:(NSURL *)URL
                        completion:(CDBErrorCompletion)completion {
    __block NSError * error = nil;
    void (^ accessor)(NSURL * writingURL) = ^(NSURL* writingURL) {
        [[NSFileManager new] removeItemAtURL:writingURL
                                       error:&error];
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSFileCoordinator * fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        
        [fileCoordinator coordinateWritingItemAtURL:URL
                                            options:NSFileCoordinatorWritingForDeleting
                                              error:nil
                                         byAccessor:accessor];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion != nil) {
                completion(error);
            }
        });
    });
}

/**
 * @brief:
 * note that we return last happend error only
**/

- (void)coordinatedRemoveItemsAtURLs:(NSArray *)URLs
                          completion:(CDBErrorCompletion)completion {
    NSMutableArray * URLsToRemove = [NSMutableArray array];
    for (NSURL * URL in URLs) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:URL.path] == NO) {
            continue;
        }
        [URLsToRemove addObject:URL];
    }
    
    if (URLsToRemove.count == 0) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }
    
    __block NSUInteger counter = URLsToRemove.count;
    __block NSError * removeError = nil;
    
    for (NSURL * URL in URLsToRemove) {
        [self coordinatedRemoveItemAtURL:URL
                              completion:^(NSError * _Nullable error) {
            if (error != nil) {
                removeError = error;
            }

            counter -= 1;

            if (counter == 0) {
                if (completion != nil) {
                    completion(removeError);
                }
            }
        }];
    }
}

#pragma mark - class -

#pragma mark duplicates handling

+ (void)performRemovingDublicatesForEntity:(NSEntityDescription *)entity
                         uniquePropertyKey:(NSString *)uniquePropertyKey
                              timestampKey:(NSString *)timestampKey
                              usingContext:(NSManagedObjectContext *)context
                                     error:(NSError **)error {
    NSError * internalError = nil;
    
    NSArray * valuesWithDupes = [self valuesWithDublicatesForEntity:entity
                                                  uniquePropertyKey:uniquePropertyKey
                                                       usingContext:context
                                                              error:&internalError];
    
    
    if (internalError != nil) {
        RLogCDB(YES, @"failed to fetch values with dupes for unique key - %@, entity %@",
                uniquePropertyKey, entity.name);
        *error = internalError;
        return;
    }
    
    RLogCDB(YES, @"found %ld not uniqued keys for entity %@",
            (unsigned long) valuesWithDupes.count, entity.name);
    
    
    internalError = nil;
    
    [self resolveDuplicatesForEntity:entity
                   uniquePropertyKey:uniquePropertyKey
                        timestampKey:timestampKey
           usingValuesWithDublicates:valuesWithDupes
                             context:context
                               error:&internalError];
    
    if (internalError != nil) {
        RLogCDB(YES, @"failed to resolve dupes for unique key - %@, timestamp key - %@, entity %@",
                uniquePropertyKey, timestampKey, entity.name);
        *error = internalError;
        return;
    }
}

+ (NSArray *)valuesWithDublicatesForEntity:(NSEntityDescription *)entity
                         uniquePropertyKey:(NSString *)uniquePropertyKey
                              usingContext:(NSManagedObjectContext *)context
                                     error:(NSError **)error {
    if (entity == nil
        || uniquePropertyKey.length == 0
        || context == nil) {
        return nil;
    }
    
    //    NSExpression * keyPathExpression = [NSExpression expressionForKeyPath:uniquePropertyKey];
    //    NSExpression * countExpression = [NSExpression expressionForFunction:@"count:" arguments:@[keyPathExpression]];
    NSExpression *countExpression = [NSExpression expressionWithFormat:@"count:(%K)", uniquePropertyKey];
    NSExpressionDescription * countExpressionDescription = [[NSExpressionDescription alloc] init];
    [countExpressionDescription setName:@"count"];
    [countExpressionDescription setExpression:countExpression];
    [countExpressionDescription setExpressionResultType:NSInteger64AttributeType];
    NSAttributeDescription * uniqueAttribute = [[entity attributesByName] objectForKey:uniquePropertyKey];
    
    NSFetchRequest * request = [NSFetchRequest fetchRequestWithEntityName:entity.name];
    [request setPropertiesToFetch:@[uniqueAttribute, countExpressionDescription]];
    [request setPropertiesToGroupBy:@[uniqueAttribute]];
    [request setResultType:NSDictionaryResultType];
    
    NSError * internalError = nil;
    
    NSArray * fetchedDictionaries = [context executeFetchRequest:request
                                                           error:&internalError];
    
    if (internalError != nil) {
        RLogCDB(YES, @"failed to execute request: %@\
                      \r using context: %@\
                      \r error: %@",
                       request, context, internalError);
        *error = internalError;
        return nil;
    }
    
    NSMutableArray * result = [NSMutableArray array];
    for (NSDictionary * dict in fetchedDictionaries) {
        NSNumber * count = dict[@"count"];
        if ([count integerValue] > 1) {
            [result addObject:dict[uniquePropertyKey]];
        }
    }
    
    return [result copy];
}

+ (void)resolveDuplicatesForEntity:(NSEntityDescription *)entity
                 uniquePropertyKey:(NSString *)uniquePropertyKey
                      timestampKey:(NSString *)timestampKey
         usingValuesWithDublicates:(NSArray *)valuesWithDupes
                           context:(NSManagedObjectContext * _Nullable)context
                             error:(NSError **)error {
    
    NSFetchRequest * dupeRequest = [NSFetchRequest fetchRequestWithEntityName:entity.name];
    [dupeRequest setIncludesPendingChanges:NO];
    NSPredicate * predicate = [NSPredicate predicateWithFormat:@"%K IN (%@)", uniquePropertyKey, valuesWithDupes];
    [dupeRequest setPredicate:predicate];
    NSSortDescriptor * uniquePropertySorted = [NSSortDescriptor sortDescriptorWithKey:uniquePropertyKey
                                                                            ascending:YES];
    [dupeRequest setSortDescriptors:@[uniquePropertySorted]];
    
    NSError * internalError = nil;
    
    NSArray * fetchedDupes = [context executeFetchRequest:dupeRequest
                                                    error:error];
    
    if (internalError != nil) {
        RLogCDB(YES, @"failed to execute dupeRequest: %@\
                \r using context: %@\
                \r error: %@",
                dupeRequest, context, internalError);
        *error = internalError;
        return;
    }
    
    NSUInteger removedDupesCount = 0;
    
    NSManagedObject * prevObject = nil;
    for (NSManagedObject * duplicate in fetchedDupes) {
        if (prevObject != nil) {
            NSString * prevObjectUniqueValue = [prevObject valueForKey:uniquePropertyKey];
            NSString * duplicateUniqueValue = [duplicate valueForKey:uniquePropertyKey];
            if ([duplicateUniqueValue isEqualToString:prevObjectUniqueValue]) {
                NSString * prevObjectTimestamp = [prevObject valueForKey:timestampKey];
                NSString * duplicateTimestamp = [duplicate valueForKey:timestampKey];
                if ([duplicateTimestamp compare:prevObjectTimestamp] == NSOrderedAscending) {
                    [context deleteObject:duplicate];
                } else {
                    [context deleteObject:prevObject];
                    prevObject = duplicate;
                }
                removedDupesCount++;
            } else {
                prevObject = duplicate;
            }
        } else {
            prevObject = duplicate;
        }
    }
    RLogCDB(YES, @"delete %ld dupes for unique key - %@, using newer timestamp logic at key - %@, entity %@",
            (unsigned long)removedDupesCount, uniquePropertyKey, timestampKey, entity.name);
}

+ (void)performBatchPopulationForEntity:(NSEntityDescription *)entity
                usingPropertiesToUpdate:(NSDictionary *)propertiesToUpdate
                              predicate:(NSPredicate *)predicate
                              inContext:(NSManagedObjectContext *)context {
    if (entity == nil
        || context == nil
        || propertiesToUpdate == nil) {
        return;
    }
    
    RLogCDB(YES, @"update entity %@ with %@", entity.name, propertiesToUpdate);
    
    NSBatchUpdateRequest * request = [[NSBatchUpdateRequest alloc] initWithEntity:entity];
    request.predicate = [NSPredicate predicateWithFormat:@"uid = nil"];
    request.propertiesToUpdate = propertiesToUpdate;
    request.resultType = NSUpdatedObjectsCountResultType;
    
    NSError * error = nil;
    NSBatchUpdateResult * result = (NSBatchUpdateResult *)[context executeRequest:request
                                                                            error:&error];
    if (error != nil) {
        RLogCDB(YES, @" failed update entity %@ with %@", entity.name, error);
        return;
    }
    
    RLogCDB(YES, @"%@ entities updated entity %@", result.result, entity.name);
}

+ (void)performBatchUIDsPopulationForEntity:(NSEntityDescription *)entity
                     usingUniquePropertyKey:(NSString *)uniquePropertyKey
                                  batchSize:(NSUInteger)batchSize
                                  inContext:(NSManagedObjectContext *)context {
    if (entity == nil
        || context == nil
        || uniquePropertyKey.length == 0) {
        return;
    }
    
    if (batchSize == 0) {
        batchSize = 1000;
    }
    
    NSFetchRequest * request = [NSFetchRequest fetchRequestWithEntityName:entity.name];
    request.predicate = [NSPredicate predicateWithFormat:@"%K = nil", uniquePropertyKey];
    request.fetchBatchSize = batchSize;
    
    NSError * error = nil;
    NSArray<NSManagedObject *> * results = [context executeFetchRequest:request
                                                                  error:&error];
    
    if (error != nil) {
        RLogCDB(YES, @" failed fetch empty UID objects for entity %@ at unique key - %@ - with %@",
                entity.name, uniquePropertyKey, error);
        return;
    }
    
    NSUInteger currentIndex = 0;
    
    while (error == nil
           && currentIndex < results.count) {
        NSUInteger maxAvailableLenght = results.count - currentIndex;
        NSUInteger length = maxAvailableLenght < batchSize ? maxAvailableLenght
                                                           : batchSize;
        NSRange currentBatchRange = NSMakeRange(currentIndex, length);
        if (NSMaxRange(currentBatchRange) <= results.count) {
            @autoreleasepool {
                NSArray * batch = [results subarrayWithRange:currentBatchRange];
                [self populateUIDsOfManagedObjects:batch
                            usingUniquePropertyKey:(NSString * _Nullable)uniquePropertyKey
                                         inContext:context
                                             error:&error];
            }
        }
        
        currentIndex = NSMaxRange(currentBatchRange);
    }
    
    if (error != nil) {
        RLogCDB(YES, @" failed update UIDs for entity %@  at unique key - %@ - with %@",
                entity.name, uniquePropertyKey, error);
        return;
    }
    
    RLogCDB(YES, @"%lu UIDs created at unique key - %@ - for entity %@",
            (unsigned long)results.count, uniquePropertyKey, entity.name);
}

+ (void)populateUIDsOfManagedObjects:(NSArray<NSManagedObject *> *)mananagedObjects
              usingUniquePropertyKey:(NSString *)uniquePropertyKey
                           inContext:(NSManagedObjectContext *)context
                               error:(NSError **)error {
    for (NSManagedObject * object in mananagedObjects) {
        [object setValue:[self generateEntityUID]
                  forKey:uniquePropertyKey];
    }
    [context performBlockAndWait:^{
        [context save:error];
        [context reset];
    }];
}

+ (void)performRemovingAllObjectsForEntity:(NSEntityDescription *)entity
                              usingContext:(NSManagedObjectContext *)context
                                 batchSize:(NSUInteger)batchSize
                                     error:(NSError **)error {
    if (entity == nil
        || context == nil) {
        return;
    }
    
    if (batchSize == 0) {
        batchSize = 1000;
    }
    
    NSFetchRequest * request = [NSFetchRequest fetchRequestWithEntityName:entity.name];
    request.fetchBatchSize = batchSize;
    
    NSArray<NSManagedObject *> * results = [context executeFetchRequest:request
                                                                  error:error];
    
    if (*error != nil) {
        RLogCDB(YES, @" failed fetch objects for entity %@ %@",
                entity.name, *error);
        return;
    }
    
    NSUInteger currentIndex = 0;
    
    while (*error == nil
           && currentIndex < results.count) {
        NSUInteger maxAvailableLenght = results.count - currentIndex;
        NSUInteger length = maxAvailableLenght < batchSize ? maxAvailableLenght
        : batchSize;
        NSRange currentBatchRange = NSMakeRange(currentIndex, length);
        if (NSMaxRange(currentBatchRange) <= results.count) {
            @autoreleasepool {
                NSArray * batch = [results subarrayWithRange:currentBatchRange];
                [self removeManagedObjects:batch
                                 inContext:context
                                     error:error];
            }
        }
        
        currentIndex = NSMaxRange(currentBatchRange);
    }
    
    if (*error != nil) {
        RLogCDB(YES, @" failed remove objects for entity %@ %@",
                entity.name, *error);
        return;
    }
}


+ (void)removeManagedObjects:(NSArray<NSManagedObject *> *)mananagedObjects
                   inContext:(NSManagedObjectContext *)context
                       error:(NSError **)error {
    for (NSManagedObject * object in mananagedObjects) {
        [context deleteObject:object];
    }
    [context performBlockAndWait:^{
        [context save:error];
        [context reset];
    }];
}

+ (NSDate *)generateTimestamp {
    NSDate * result = [NSDate date];
    return result;
}

+ (NSString *)generateEntityUID {
    NSString * result = [CDBUUID UUIDString];
    return result;
}

@end
