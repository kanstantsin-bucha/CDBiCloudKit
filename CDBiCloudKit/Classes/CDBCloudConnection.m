

#import "CDBCloudConnection.h"


NSString * _Nonnull CDBCloudConnectionDidChangeState = @"CDBCloudConnectionDidChangeState";


#define CDB_Store_Ubiqutos_Token @".CDB.CDBCloudStore.store.ubiquitos.token=NSObject"


@interface CDBCloudConnection ()

@property (assign, nonatomic, readwrite) CDBCloudState state;

@property (strong, nonatomic, readwrite) CDBCloudDocuments * documents;
@property (strong, nonatomic, readwrite) CDBCloudStore * store;


@property (copy, nonatomic) NSString * containerID;
@property (copy, nonatomic) NSString * documentsPathComponent;
@property (copy, nonatomic) NSString * storeName;
@property (strong, nonatomic) NSURL * storeModelURL;


@property (strong, nonatomic, readonly) NSFileManager * fileManager;
@property (nonatomic, strong) NSURL * ubiquityContainerURL;
@property (strong, nonatomic) id<NSObject,NSCopying,NSCoding> ubiquityIdentityToken;
@property (assign, nonatomic, readwrite) BOOL usingSameUbiquityContainer;

@end


@implementation CDBCloudConnection

#pragma mark - property -

- (NSFileManager *)fileManager {
    NSFileManager * result = [NSFileManager new];
    return result;
}

- (BOOL)isInitiated {
    BOOL result = self.containerID.length > 0;
    return result;
}

- (BOOL)ubiquitosActive {
    BOOL result = self.ubiquitosDesired
                  && self.state == CDBCloudUbiquitosContentAvailable;
    return result;
}

- (void)setUbiquitosDesired:(BOOL)ubiquitosDesired {
    if (_ubiquitosDesired == ubiquitosDesired) {
        return;
    }
    
    _ubiquitosDesired = ubiquitosDesired;
    [self applyCurrentState];
}

#pragma mark - lazy loading - 

- (CDBCloudDocuments *)documents {
    if (_documents == nil
        && self.isInitiated) {
        _documents = [CDBCloudDocuments new];
        [_documents initiateUsingCloudPathComponent:self.documentsPathComponent];
        [_documents updateForUbiquityActive:self.ubiquitosActive
                  usingUbiquityContainerURL:self.ubiquityContainerURL];
    }
    return _documents;
}

- (CDBCloudStore *)store {
    if (_store == nil
        && self.isInitiated
        && self.storeName.length > 0
        && self.storeModelURL.path.length > 0) {
        _store = [CDBCloudStore new];
        [_store initiateWithName:self.storeName
                        modelURL:self.storeModelURL];
        [_store updateForUbiquityActive:self.ubiquitosActive
             usingSameUbiquityContainer:self.usingSameUbiquityContainer
                                withURL:self.ubiquityContainerURL];
    }
    return _store;
}

#pragma mark - notifications -

- (void)subscribeToNotifications {
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(cloudContentAvailabilityChanged:)
                                                 name: NSUbiquityIdentityDidChangeNotification
                                               object: nil];
}


- (void)postNotificationUsingName:(NSString *)name {
    [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                        object:self];
}

#pragma mark - life cycle -

+ (instancetype)sharedInstance {
    static CDBCloudConnection * _sharedInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        _sharedInstance = [[super allocWithZone:NULL] init];
    });
    return _sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [self sharedInstance];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)initiateWithUbiquityDesired:(BOOL)desired
           usingContainerIdentifier:(NSString * _Nullable)ID
             documentsPathComponent:(NSString * _Nullable)pathComponent
                          storeName:(NSString * _Nullable)storeName
                      storeModelURL:(NSURL * _Nullable)storeModelURL
                           delegete:(id<CDBCloudConnectionDelegate>)delegate {
    self.ubiquitosDesired = desired;
    self.containerID = ID;
    self.documentsPathComponent = pathComponent;
    self.storeName = storeName;
    self.storeModelURL = storeModelURL;
    self.delegate = delegate;
    
    [self subscribeToNotifications];
    [self applyCurrentState];
}

#pragma mark - public -

- (void)showDeniedAccessAlert {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:LSCDB(iCloud Unavailable)
                                                     message:LSCDB(Make sure that you are signed into a valid iCloud account and documents are Enabled)
                                                    delegate:nil
                                           cancelButtonTitle:LSCDB(OK)
                                           otherButtonTitles:nil];
    [alert show];
}

#pragma mark - private -

#pragma mark handle state changes

- (void)applyCurrentState {
    [self performCloudStateCheckWithCompletion:^{
        if (self.ubiquitosDesired
            && self.state == CDBCloudAccessDenied) {
            [self handleDeniedAccess];
        }
        
        [self handleStateChanges];
        [self postNotificationUsingName:CDBCloudConnectionDidChangeState];
    }];
}

- (void)handleDeniedAccess {
    if ([self.delegate respondsToSelector:@selector(CDBCloudConnectionDidDetectDisabledCloud:)]) {
        [self.delegate CDBCloudConnectionDidDetectDisabledCloud:self];
    } else {
        [self showDeniedAccessAlert];
    }
}

- (void)handleStateChanges {
    if ([self.delegate respondsToSelector:@selector(CDBCloudConnectionDidChangeState:)]) {
        [self.delegate CDBCloudConnectionDidChangeState:self];
    } else {
        [self provideStateChanges];
    }
}

- (void)provideStateChanges {
    [_documents updateForUbiquityActive:self.ubiquitosActive
              usingUbiquityContainerURL:self.ubiquityContainerURL];
    [_store updateForUbiquityActive:self.ubiquitosActive
         usingSameUbiquityContainer:self.usingSameUbiquityContainer
                            withURL:self.ubiquityContainerURL];
}

- (void)cloudContentAvailabilityChanged:(NSNotification *)notification {
    [self applyCurrentState];
}

- (void)performCloudStateCheckWithCompletion:(dispatch_block_t)completion {
    dispatch_async(dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSURL * ubiquityContainerURL = nil;
        id ubiquityIdentityToken = [self.fileManager ubiquityIdentityToken];
        if (ubiquityIdentityToken != nil) {
            ubiquityContainerURL = [self.fileManager URLForUbiquityContainerIdentifier:self.containerID];
        }
        dispatch_async(dispatch_get_main_queue (), ^(void) {
            BOOL cloudIsAvailable = ubiquityIdentityToken != nil;
            BOOL ubiquityContainerIsAvailable = ubiquityContainerURL != nil;
            
            CDBCloudState currentState;
            
            if (ubiquityContainerIsAvailable == NO) {
                currentState = CDBCloudAccessGranted;
            } else {
                currentState = CDBCloudUbiquitosContentAvailable;
            }
            
            if (cloudIsAvailable == NO) {
                currentState = CDBCloudAccessDenied;
            } else {
                id previousUbiquityIdentityToken = [self loadPreviousUbiquityIdentityToken];
                self.usingSameUbiquityContainer = [ubiquityIdentityToken isEqual:previousUbiquityIdentityToken];
                [self saveUbiquityIdentityToken:ubiquityIdentityToken];
            }
            
            self.ubiquityContainerURL = ubiquityContainerURL;
            self.ubiquityIdentityToken = ubiquityIdentityToken;
            self.state = currentState;
            
            if (completion != nil) {
                completion();
            }
        });
    });
}

#pragma mark CDB.CDBCloudStore.store.ubiquitos.token=NSObject

- (void)saveUbiquityIdentityToken:(id<NSObject, NSCoding, NSCopying>)token {
    if (token == nil) {
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:token
                                              forKey:CDB_Store_Ubiqutos_Token];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id<NSObject, NSCoding, NSCopying>)loadPreviousUbiquityIdentityToken {
    
    id<NSObject, NSCoding, NSCopying> result =
        [[NSUserDefaults standardUserDefaults] objectForKey:CDB_Store_Ubiqutos_Token];
    return result;
}

@end
