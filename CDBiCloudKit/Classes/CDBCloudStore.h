

#if __has_feature(objc_modules)
    @import Foundation;
    @import UIKit;
    @import CoreData;
#else
    #import <Foundation/Foundation.h>
    #import <UIKit/UIKit.h>
    #import <CoreData/CoreData.h>
#endif


#import <CDBKit/CDBKit.h>
#import "CDBiCloudKitConstants.h"


extern NSString * _Nonnull CDBCloudStoreWillChangeNotification;
extern NSString * _Nonnull CDBCloudStoreDidChangeNotification;


@protocol CDBCloudStoreDelegate;


BOOL CDBCheckStoreState(CDBCloudStoreState state, NSUInteger option);


@interface CDBCloudStore : NSObject

@property (assign, nonatomic, readonly) BOOL ubiquitous;
@property (strong, nonatomic, readonly, nullable) NSManagedObjectContext * currentContext;
@property (weak, nonatomic, nullable) id<CDBCloudStoreDelegate> delegate;

/**
 * @brief
 * if selected but not active then cloud initial sync didn't finish yet and we use local store
 * when (set local storage: 0) appears we switch to ubiquitos store and set
 CDBCloudStoreUbiquitosActive to 1
 CDBCloudStoreUbiquitosInitiated to 1
 
 * if user removes cloud content we switch to local store, post notification and set
 CDBCloudStoreUbiquitosSelected to 0
 CDBCloudStoreUbiquitosInitiated to 0
 CDBCloudStoreUbiquitosActive to 0
 
 * if user log out from cloud we switch to local store while waiting for log in and set
 CDBCloudStoreUbiquitosActive to 0
 **/

@property (assign, nonatomic, readonly) CDBCloudStoreState state;


@property (strong, nonatomic, readonly, nullable) NSURL * modelURL;
@property (strong, nonatomic, readonly, nullable) NSString * name;
@property (strong, nonatomic, readonly, nullable) NSManagedObjectModel * model;

@property (assign, nonatomic, readonly) BOOL localStoreDisabled;
@property (strong, nonatomic, readonly, nullable) NSManagedObjectContext * localContext;
@property (strong, nonatomic, readonly, nullable) NSPersistentStore * localStore;
@property (strong, nonatomic, nullable) NSDictionary * localStoreOptions;
@property (strong, nonatomic, readonly, nullable) NSURL * localStoreURL;
@property (strong, nonatomic, readonly, nullable) NSPersistentStoreCoordinator * localStoreCoordinator;

@property (assign, nonatomic, readonly) BOOL ubiquitosStoreDisabled;
@property (strong, nonatomic, readonly, nullable) NSManagedObjectContext * ubiquitosContext;
@property (strong, nonatomic, readonly, nullable) NSPersistentStore * ubiqutosStore;
@property (strong, nonatomic, nullable) NSDictionary * ubiquitosStoreOptions;
@property (strong, nonatomic, readonly, nullable) NSURL * ubiquitosStoreURL;
@property (strong, nonatomic, readonly, nullable) NSPersistentStoreCoordinator * ubiquitosStoreCoordinator;


- (void)initiateWithName:(NSString * _Nonnull)storeName
                modelURL:(NSURL * _Nonnull)modelURL;

- (void)updateForUbiquityActive:(BOOL)available
     usingSameUbiquityContainer:(BOOL)sameUbiquityContainer
                        withURL:(NSURL * _Nullable)containerURL;


- (void)dismissAndDisableLocalCoreDataStack;
- (void)enableLocalCoreDataStack;

- (void)dismissAndDisableUbiquitosCoreDataStack;
- (void)enableUbiquitosCoreDataStack;

- (void)mergeUbiquitousContentChanges:(NSNotification * _Nullable)changeNotification
                         usingContext:(NSManagedObjectContext * _Nonnull)context;

/**
 * @brief
 * remove local store and migrate ubiquitos to it's place
 * this method dissmiss local store during execution
 * if removing fails it try to populate local store with ubiquitos content
 **/

- (void)replaceLocalStoreUsingUbiquitosOneWithCompletion:(CDBErrorCompletion _Nullable)completion;

/**
 * @brief
 * remove ubiquitos store and recreate it using cloud ubiquitos content
 * this method restart ubiquitos store using rebuild option
 * so be aware of stright coping this store option - use ubiquitosStoreOptions instead
 **/

- (void)rebuildUbiquitosStoreFromUbiquitousContenWithCompletion:(CDBErrorCompletion _Nullable)completion;

/**
 * @brief
 * remove all ubiquitos content from this device only
 * note that it returns last happend error only
 * this method dissmiss ubiquitos store during execution
 **/

- (void)removeLocalUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion;

/**
 * @brief
 * remove all ubiquitos content from the cloud and all devices
 * this method dissmiss all stores during execution
 **/

- (void)removeAllUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion;


/**
 * @brief
 * remove all ubiquitos content from the cloud and all devices
 * this method clears ubiquitos store during execution than save context
 **/

- (void)removeAllUbiquitousStoreDataWithCompletion:(CDBErrorCompletion _Nullable)completion;


/**
 * @brief
 * remove store at URL and it's cach files too
 * store should be closed (it should have no connected store coordinators)
 **/

- (void)removeCoreDataStoreAtURL:(NSURL * _Nonnull)URL
                      completion:(CDBErrorCompletion _Nullable)completion;

- (NSPersistentStoreCoordinator * _Nullable)defaultStoreCoordinator;

#pragma mark deduplication helpers

+ (void)performRemovingDublicatesForEntity:(NSEntityDescription * _Nonnull)entity
                         uniquePropertyKey:(NSString * _Nonnull)uniquePropertyKey
                              timestampKey:(NSString * _Nonnull)timestampKey
                              usingContext:(NSManagedObjectContext * _Nonnull)context
                                     error:(NSError * _Nullable __autoreleasing * _Nullable)error;

+ (void)performBatchPopulationForEntity:(NSEntityDescription * _Nonnull)entity
                usingPropertiesToUpdate:(NSDictionary * _Nonnull)propertiesToUpdate
                              predicate:(NSPredicate * _Nonnull)predicate
                              inContext:(NSManagedObjectContext * _Nonnull)context;

+ (void)performBatchUIDsPopulationForEntity:(NSEntityDescription * _Nonnull)entity
                     usingUniquePropertyKey:(NSString * _Nonnull)uniquePropertyKey
                                  batchSize:(NSUInteger)batchSize
                                  inContext:(NSManagedObjectContext * _Nonnull)context;

+ (NSDate * _Nonnull)generateTimestamp;
+ (NSString * _Nonnull)generateEntityUID;

@end


@protocol CDBCloudStoreDelegate <NSObject>

@optional

/**
 * @brief
 * called when store switching current context
 * called before store changes it's state
 * both stores online so you could migrate you data from store to store there
 * please don't change selected state inside this methods
 **/

- (void)ubiquitousActivationBeginAtCDBCloudStore:(CDBCloudStore * _Nullable)store;
- (void)localActivationBeginAtCDBCloudStore:(CDBCloudStore * _Nullable)store;

/**
 * @brief
 * called when store imported cloud changes
 * you could provide your custom logic there
 * after merging changes using [ mergeUbiquitousContentChanges: usingContext:] method
 *
 * if this method not implemented in delegate store use
 * using [ mergeUbiquitousContentChangesUsing:] method automatically
 **/

- (void)CDBCloudStore:(CDBCloudStore * _Nullable)store
    didImportUbiquitousContentChanges:(NSNotification * _Nullable)changeNotification;

/**
 * @brief
 * called when store created core data stack (storeCoordinator, store)
 * called before store changes it's state
 * usually it happends when app request context or on selecting different store
 *
 * you could perform some core data tasks with store here before it data comes to UI
 **/

//- (void)didCreateUbiquitosCoreDataStackOfCDBCloudStore:(CDBCloudStore * _Nullable)store;
//- (void)didCreateLocalCoreDataStackOfCDBCloudStore:(CDBCloudStore * _Nullable)store;

- (void)didChangeStateOfCDBCloudStore:(CDBCloudStore * _Nullable)store;

/**
 * @brief
 * called when user remove (clear) all cloud data 
 * store changes to local automatically after delegate call
 * called before store changes it's state
 * you probably should migrate you cloud data to local on this call or lose it forever
 **/

- (void)didDetectThatUserWillRemoveContentOfCDBCloudStore:(CDBCloudStore * _Nullable)store;

@end
