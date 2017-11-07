

#import <Foundation/Foundation.h>
#import <CDBKit/CDBKitCore.h>


#import "CDBCloudDocuments.h"
#import "CDBCloudStore.h"


extern NSString * _Nonnull CDBCloudConnectionDidChangeState;


typedef NS_ENUM(NSUInteger, CDBCloudState) {
    CDBCloudStateUndefined = 0,
    CDBCloudAccessDenied = 1,
    CDBCloudAccessGranted = 2,
    CDBCloudUbiquitosContentAvailable = 3, // Connection established
};

#define StringFromCloudState(enum) (([@[\
@"CDBCloudStateUndefined",\
@"CDBCloudAccessDenied",\
@"CDBCloudAccessGranted",\
@"CDBCloudUbiquitosConеtentAvailable",\
] objectAtIndex:(enum)]))


@protocol CDBCloudConnectionDelegate;


@interface CDBCloudConnection : NSObject

/**
 Contains connection state
 **/

@property (assign, nonatomic, readonly) CDBCloudState state;
@property (weak, nonatomic, nullable) id<CDBCloudConnectionDelegate> delegate;

@property (strong, nonatomic, readonly, nullable) NSURL * ubiquityContainerURL;
@property (strong, nonatomic, readonly, nullable) id ubiquityIdentityToken;

@property (strong, nonatomic, readonly, nullable) CDBCloudDocuments * documents;
@property (strong, nonatomic, readonly, nullable) CDBCloudStore * store;

@property (assign, nonatomic, readonly) BOOL ubiquitosActive;
@property (assign, nonatomic, readonly) BOOL usingSameUbiquityContainer;

@property (assign, nonatomic) BOOL ubiquitosDesired;

+ (instancetype _Nullable)sharedInstance;

- (void) initiateWithUbiquityDesired: (BOOL) desired
            usingContainerIdentifier: (NSString * _Nullable) containerID
              documentsPathComponent: (NSString * _Nullable) pathComponent
                  appGroupIdentifier: (NSString * _Nullable) appGroupID
                           storeName: (NSString * _Nullable) storeName
                       storeModelURL: (NSURL * _Nullable) storeModelURL
                            delegete: (id<CDBCloudConnectionDelegate> _Nullable) delegate;

- (void)provideStateChanges;
             

@end


@protocol CDBCloudConnectionDelegate <NSObject>

@optional

/**
 default implemetation provide state changes to the documents and cloud
 if you override this method you should provide statechanges by itelf
 or calling [ provideStateChanges] method
 **/
- (void)CDBCloudConnectionDidChangeState:(CDBCloudConnection * _Nonnull)connection;
- (void)CDBCloudConnectionDidDetectDisabledCloud:(CDBCloudConnection * _Nonnull)connection;


@end
