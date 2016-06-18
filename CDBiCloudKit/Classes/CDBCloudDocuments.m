

#import "CDBCloudDocuments.h"


#define CDBiCloudDocumentsDirectoryPathComponent @"Documents"
#define CDB_Documents_Processing_Last_Date_Format @"CDB.CDBiCloudReady.documents.%@.processedDate=NSDate"


@interface CDBCloudDocuments ()

@property (assign, nonatomic, readwrite) BOOL ubiquitosActive;
@property (assign, nonatomic, readonly) BOOL ubiquityContainerAccessible;

@property (copy, nonatomic) NSString * cloudPathComponent;
@property (copy, nonatomic) NSString * requestedFilesExtension;

@property (strong, nonatomic) CDBDocument * documentsDirectoryWatchdog;

@property (strong, nonatomic) NSMutableSet <NSURL *> * uniqueCloudDocumentURLs;

@property (weak, nonatomic) id<CDBCloudDocumentsDelegate> delegate;

@property (strong, nonatomic) NSMetadataQuery * metadataQuery;
@property (strong, nonatomic, readonly) NSFileManager * fileManager;
@property (nonatomic, strong) NSURL * ubiquityContainerURL;

@property (strong, nonatomic) dispatch_queue_t serialQueue;

@end


@implementation CDBCloudDocuments
@synthesize localDocumentsURL = _localDocumentsURL;

#pragma mark - property -


- (NSURL *)presentedItemURL {
    return nil;
}

#pragma mark Getter

- (__strong dispatch_queue_t)serialQueue {
    if (_serialQueue == nil) {
        _serialQueue =  dispatch_queue_create("CDB.iCloudReady.CloudDocuments.GCD.queue.serial", DISPATCH_QUEUE_SERIAL);
    }
    return _serialQueue;
}

- (NSArray<NSURL *> *)cloudDocumentURLs {
    NSArray * result = self.uniqueCloudDocumentURLs.allObjects;
    return result;
}

- (NSURL *)currentDocumentsURL {
    NSURL * result = nil;
    if (self.ubiquitosActive) {
        result = self.ubiquityDocumentsURL;
    } else {
        result = self.localDocumentsURL;
    }
    return result;
}

- (BOOL)ubiquityContainerAccessible {
    BOOL result = self.ubiquityContainerURL != nil;
    return result;
}

- (NSURL *)ubiquityDocumentsURL {
    NSURL * result =
        [self.ubiquityContainerURL URLByAppendingPathComponent:self.cloudPathComponent
                                                   isDirectory:YES];
    return result;
}

- (NSFileManager *)fileManager {
    NSFileManager * result = [NSFileManager new];
    return result;
}

- (NSPredicate *)requestedFilesMetadataPredicate {
    NSString * format = [NSString stringWithFormat:@"%%K.pathExtension LIKE '%@'", self.requestedFilesExtension];
    NSPredicate * result = [NSPredicate predicateWithFormat:format, NSMetadataItemFSNameKey];
    return result;
}

- (NSError *)iCloudNotAcceessableError {
    NSString * errorDescription = @"iCloud not available";
    NSDictionary * userInfo = @{NSLocalizedDescriptionKey: errorDescription};
    NSError * result = [NSError errorWithDomain:NSStringFromClass([self class])
                                           code:0
                                       userInfo:userInfo];
    return result;
}

- (NSError *)fileNameCouldNotBeEmptyError {
    NSString * errorDescription = @"Could not process empty file name";
    NSDictionary * userInfo = @{NSLocalizedDescriptionKey: errorDescription};
    NSError * result = [NSError errorWithDomain:NSStringFromClass([self class])
                                           code:1
                                       userInfo:userInfo];
    return result;
}

- (NSError *)fileNameCouldNotBeDirectoryError {
    NSString * errorDescription = @"Could not process file name that represents directory";
    NSDictionary * userInfo = @{NSLocalizedDescriptionKey: errorDescription};
    NSError * result = [NSError errorWithDomain:NSStringFromClass([self class])
                                           code:1
                                       userInfo:userInfo];
    return result;
}

- (NSError *)directoryUnacceptableURLErrorUsingURL:(NSURL *)URL {
    NSString * errorDescription = [NSString stringWithFormat:@"Could not handle nil or empty URL: %@", URL];
    NSDictionary * userInfo = @{NSLocalizedDescriptionKey: errorDescription};
    NSError * result = [NSError errorWithDomain:NSStringFromClass([self class])
                                           code:2
                                       userInfo:userInfo];
    return result;
}

#pragma mark Setter

- (void)setLocalDocumentsURL:(NSURL *)localDocumentsURL {
    if ([_localDocumentsURL.path isEqualToString:localDocumentsURL.path]) {
        return;
    }
    
    [self synchronousEnsureThatDirectoryPresentsAtURL:localDocumentsURL
                                            comletion:^(NSError *error) {
        if (error != nil) {
            NSLog(@"[CDBCloudDocuments] could not resolve local documents URL %@\
                  \n failed with error: %@",
                  localDocumentsURL, error);
        } else {
            _localDocumentsURL = localDocumentsURL;
        }
    }];
}

#pragma mark Lazy loading

- (NSMutableSet<NSURL *> *)uniqueCloudDocumentURLs {
    if (_uniqueCloudDocumentURLs != nil) {
        return _uniqueCloudDocumentURLs;
    }
    
    _uniqueCloudDocumentURLs = [NSMutableSet set];
    return _uniqueCloudDocumentURLs;
}

- (NSURL *)localDocumentsURL {
    if (_localDocumentsURL == nil) {
        NSArray * URLs = [self.fileManager URLsForDirectory:NSDocumentDirectory
                                                  inDomains:NSUserDomainMask];
        _localDocumentsURL = [URLs lastObject];
    }
    return _localDocumentsURL;
}

- (NSMetadataQuery *)metadataQuery {
    if (_metadataQuery == nil) {
        _metadataQuery = [NSMetadataQuery new];
    }
    return _metadataQuery;
}

#pragma mark - life cycle -

- (void)initiateUsingCloudPathComponent:(NSString * _Nullable)pathComponent {
    if (pathComponent.length == 0) {
        self.cloudPathComponent = CDBiCloudDocumentsDirectoryPathComponent;
    } else {
        self.cloudPathComponent = pathComponent;
    }
    
    self.requestedFilesExtension = @"*";
}

#pragma mark - Notifications -

- (void)handleMetadataQueryDidUpdateNotification:(NSNotification *)notification {
    [self updateFilesWithCompletion:^{}];
    [self logMetadataQueryNotification:notification];
}

- (void)handleMetadataQueryDidFinishGatheringNotification:(NSNotification *)notification {
    [self updateFilesWithCompletion:^{}];
    [self logMetadataQueryNotification:notification];
}

#pragma mark - Protocols -

#pragma mark CDBDocumentDelegate

- (void)didAutoresolveConflictInCDBDocument:(CDBDocument *)document {
    [self notifyDelegateThatDocumentsDidAutoresolveConflictInCDBDocument:document];
}

- (void)CDBDocumentDirectory:(CDBDocument *)document
       didChangeSubitemAtURL:(NSURL *)URL {
    if (document != self.documentsDirectoryWatchdog) {
        return;
    }
    
    // correct path to foundation private on device
    NSURL * correctedURL = URL;
    NSString * path = URL.path;
    if (self.ubiquityContainerURL.path.length > 10
        && [[self.ubiquityContainerURL.path substringToIndex:9] isEqualToString:@"/private/"]
        && path.length > 6
        && [[path substringToIndex:5] isEqualToString:@"/var/"]) {
        correctedURL = [NSURL fileURLWithPath:[@"/private" stringByAppendingString:path]];
    }
    
    BOOL removed = [self.fileManager isUbiquitousItemAtURL:correctedURL] == NO;
    if (removed) {
        [self.uniqueCloudDocumentURLs removeObject:correctedURL];
        [self notifyDelegateThatDocumentsDidRemoveUbiquitosDocumentAtURL:correctedURL];
     
        return;
    }
    [self.uniqueCloudDocumentURLs addObject:correctedURL];
    [self notifyDelegateThatDocumentsDidChangeUbiquitosDocumentAtURL:correctedURL];
}

#pragma mark - Public -

#pragma mark Handle state changes

- (void)updateForUbiquityActive:(BOOL)active
      usingUbiquityContainerURL:(NSURL *)containerURL {
    
    BOOL shouldPostChangeNotificaton = [containerURL isEqual:self.ubiquityContainerURL] == NO
                                       && containerURL != nil;
    
    self.ubiquityContainerURL = containerURL;

    if (active
        && self.ubiquitosActive == NO) {
        [self ensureThatUbiquitousDocumentsDirectoryPresents];
        [self startSynchronizationWithCompletion:nil];
        self.ubiquitosActive = YES;
        shouldPostChangeNotificaton = YES;
    } else if (active == NO
               && self.ubiquitosActive == YES) {
        [self dissmissSynchronization];
        self.ubiquitosActive = NO;
        shouldPostChangeNotificaton = YES;
    }
    
    
    if (shouldPostChangeNotificaton) {
        DLogCDB(@"update for ubiquity available %@\
              \r with container %@",
              NSStringFromBool(active),
              self.ubiquityContainerURL);
        [self notifyDelegateThatDocumentsDidChangeState];
    }
}

- (NSArray *)URLsForItemsInsideUbiquitosDirectory:(NSURL *)directory {
    NSMutableArray * result = [NSMutableArray array];
    for (NSURL * URL in self.cloudDocumentURLs) {
        NSString * relativeURLString = [self relativeURLStringFromURL:URL
                                                         usingBaseURL:directory];
        if (relativeURLString == nil) {
            continue;
        }
        
        [result addObject:URL];
    }
    return [result copy];
}

- (NSString *)documentAliasUsingItURL:(NSURL *)URL {
    NSString * result = [self relativeURLStringFromURL:URL
                                          usingBaseURL:self.currentDocumentsURL];
    return result;
}

- (void)addDelegate:(id<CDBCloudDocumentsDelegate> _Nonnull)delegate {
    self.delegate = delegate;
}

- (void)removeDelegate:(id<CDBCloudDocumentsDelegate> _Nonnull)delegate {
    if (self.delegate != delegate) {
        return;
    }
    self.delegate = nil;
}

- (void)makeDocument:(CDBDocument * _Nonnull)document
          ubiquitous:(BOOL)ubiquitous
          completion:(CDBErrorCompletion _Nonnull)completion {
    if ([document isUbiquitous] == ubiquitous) {
        completion(nil);
        return;
    }
    
    void (^ handler)(BOOL success) = ^(BOOL success) {
        if (success == NO) {
            completion(document.iCloudDocumentNotOperableError);
            return;
        }
        
        [self makeClosedDocument:document
                      ubiquitous:ubiquitous
                      completion:completion];
    };
    
    if (document.isClosed) {
        handler(YES);
        return;
    }
    
    [document closeWithCompletionHandler:^(BOOL success) {
        handler(success);
    }];
}

- (CDBDocument *)localDocumentWithFileName:(NSString *)fileName
                                     error:(NSError *_Nullable __autoreleasing * _Nullable)error {
    if (fileName.length == 0) {
        *error = [self fileNameCouldNotBeEmptyError];
        return nil;
    }
    
    NSURL * fileURL = [self localDocumentFileURLUsingFileName:fileName];
    
    CDBDocument * result = [self documentWithAvailableFileURL:fileURL
                                                              error:error];
    return result;
}

- (CDBDocument *)ubiquitousDocumentWithFileName:(NSString *)fileName
                                                error:(NSError *_Nullable __autoreleasing * _Nullable)error; {
    if (fileName.length == 0) {
        *error = [self fileNameCouldNotBeEmptyError];
        return nil;
    }
    
    if (self.ubiquityContainerAccessible == NO) {
        *error = [self iCloudNotAcceessableError];
        return nil;
    }
    
    NSURL * fileURL = [self ubiquityDocumentFileURLUsingFileName:fileName];
    
    CDBDocument * result = [self documentWithAvailableFileURL:fileURL
                                                              error:error];
    return result;
}

- (void)createClosedLocalDocumentUsingFileName:(NSString * _Nonnull)fileName
                               documentContent:(NSData * _Nullable)content
                                    completion:(CDBiCloudDocumentCompletion _Nonnull)completion {
    if (fileName.length == 0) {
        completion(nil, [self fileNameCouldNotBeEmptyError]);
        return;
    }
    
    NSURL * fileURL = [self localDocumentFileURLUsingFileName:fileName];
    
    CDBDocument * result = [[CDBDocument alloc] initWithFileURL:fileURL];
    result.contents = content;
    
    BOOL directory = NO;
    BOOL exist = [self.fileManager fileExistsAtPath:result.fileURL.path
                                        isDirectory:&directory];
    
    if (directory) {
        completion (nil, [self fileNameCouldNotBeDirectoryError]);
        return;
    }
    
    UIDocumentSaveOperation operation = exist ? UIDocumentSaveForOverwriting
                                              : UIDocumentSaveForCreating;
    
    dispatch_async(self.serialQueue, ^(void) {
        [result saveToURL:result.fileURL
         forSaveOperation:operation
        completionHandler:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    completion(result, nil);
                    return;
                }
                completion(nil, [result iCloudDocumentNotOperableError]);
            });
        }];
    });
}

- (void)readContentOfDocumentAtURL:(NSURL *)URL
                        completion:(void(^)(NSData * data, NSError * error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSData *data = nil;
        __block NSError *error = nil;
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [coordinator coordinateReadingItemAtURL:URL
                                        options:0
                                          error:&error
                                     byAccessor:^(NSURL *newURL) {
                                         data = [NSData dataWithContentsOfURL:newURL];
                                     }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion != nil) {
                completion(data, error);
            }
        });
    });
}

- (void)deleteDocument:(CDBDocument * _Nonnull)document
            completion:(CDBErrorCompletion _Nonnull)completion {
    if (document.isUbiquitous
        && self.ubiquityContainerAccessible == NO) {
        completion([self iCloudNotAcceessableError]);
        return;
    }
    
    void (^ handler)(BOOL success) = ^(BOOL success) {
        if (success == NO) {
            completion(document.iCloudDocumentNotOperableError);
            return;
        }
        [self deleteClosedDocument:document
                        completion:completion];
    };
    
    if (document.isClosed) {
        handler(YES);
        return;
    }
    
    [document closeWithCompletionHandler:^(BOOL success) {
        handler(success);
    }];
}

- (void)copyDocument:(CDBDocument * _Nonnull)document
               toURL:(NSURL * _Nonnull)destinationURL
             replace:(BOOL)replace
          completion:(CDBErrorCompletion _Nonnull)completion {
    
    if (destinationURL.path.length == 0) {
        completion([self fileNameCouldNotBeEmptyError]);
        return;
    }
    
    if (document.isUbiquitous
        && self.ubiquityContainerAccessible == NO) {
        completion([self iCloudNotAcceessableError]);
        return;
    }
    
    void (^ handler)(BOOL success) = ^(BOOL success) {
        if (success == NO) {
            completion(document.iCloudDocumentNotOperableError);
            return;
        }
        [self copyClosedDocument:document
                           toURL:destinationURL
                         replace:replace
                      completion:completion];
    };
    
    if (document.isClosed) {
        handler(YES);
        return;
    }
    
    [document closeWithCompletionHandler:^(BOOL success) {
        handler(success);
    }];
}

- (void)moveDocument:(CDBDocument * _Nonnull)document
               toURL:(NSURL * _Nonnull)destinationURL
          completion:(CDBErrorCompletion _Nonnull)completion {
    
    if (destinationURL.path.length == 0) {
        completion([self fileNameCouldNotBeEmptyError]);
        return;
    }
    
    if (document.isUbiquitous
        && self.ubiquityContainerAccessible == NO) {
        completion([self iCloudNotAcceessableError]);
        return;
    }
    
    void (^ handler)(BOOL success) = ^(BOOL success) {
        if (success == NO) {
            completion(document.iCloudDocumentNotOperableError);
            return;
        }
        [self moveClosedDocument:document
                           toURL:destinationURL
                      completion:completion];
    };
    
    if (document.isClosed) {
        handler(YES);
        return;
    }
    
    [document closeWithCompletionHandler:^(BOOL success) {
        handler(success);
    }];
}

#pragma mark document contents handling

- (void)processDocumentWithName:(NSString *)name
                          atURL:(NSURL *)URL
                processingBlock:(void(^) (NSData * documentData, NSError * error))processingBlock {
    if (processingBlock == nil
       || name.length == 0) {
        return;
    }
    
    dispatch_async(self.serialQueue, ^(void) {
        NSError * error = nil;
        NSDate * incomingDate = nil;
        [URL getResourceValue:&incomingDate
                       forKey:NSURLContentModificationDateKey
                        error:&error];
        
        if (error != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                processingBlock(nil, error);
            });
            return;
        }
        
        NSDate * lastProcessedDate = [self lastProcessedDateForDocumentWithName:name];
        BOOL should = lastProcessedDate == nil
                      || [lastProcessedDate compare:incomingDate] == NSOrderedAscending;
        if (should == NO) {
            return;
        }
        
        [self saveProcessedDate:incomingDate
            forDocumentWithName:name];
        
        [self readContentOfDocumentAtURL:URL
                              completion:^(NSData *data, NSError *error) {
            if (error != nil) {
                // restore processed date because we failed to process
                [self saveProcessedDate:lastProcessedDate
                    forDocumentWithName:name];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                processingBlock(data, error);
            });
        }];
    });
}

- (void)processStringsDocumentWithName:(NSString *)name
                                 atURL:(NSURL *)URL
               separationCharactersSet:(NSCharacterSet *)separators
                     onlyUniqueStrings:(BOOL)unique
                processingStringsBlock:(void(^) (NSArray * documentStrings, NSError * error))stringsProcessingBlock {
    if (stringsProcessingBlock == nil) {
        return;
    }
    
  
    [self processDocumentWithName:name
                            atURL:URL
                  processingBlock:^(NSData * documentData, NSError *error) {
        if (error != nil) {
            stringsProcessingBlock(nil, error);
            return;
        }

        NSString * content = [[NSString alloc] initWithData:documentData
                                                  encoding:NSUTF8StringEncoding];
        if (content == nil) {
            // preserve windows users
            content = [[NSString alloc] initWithData:documentData
                                            encoding:NSASCIIStringEncoding];
        }

        if (content == nil) {
            stringsProcessingBlock(nil, [NSError errorWithDomain:NSStringFromClass([self class])
                                                            code:0
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert file data to strings"}]);
            return;
        }

        NSArray * stringsToProcess = [content componentsSeparatedByCharactersInSet:separators];
        if (unique) {
            NSSet * uniqueStrings = [NSSet setWithArray:stringsToProcess];
            stringsToProcess = uniqueStrings.allObjects;
        }
       
        stringsProcessingBlock(stringsToProcess, nil);
    }];

}


#pragma mark - Private -

#pragma mark Safe working with files

- (void)deleteClosedDocument:(CDBDocument * _Nonnull)document
                  completion:(CDBErrorCompletion _Nonnull)completion {
    dispatch_async(self.serialQueue, ^(void) {
        __block NSError * deletetionError = nil;
        
        void (^accessor)(NSURL *) = ^(NSURL * newURL1) {
            [self.fileManager removeItemAtURL:newURL1
                                        error:&deletetionError];
        };

        // we need this error because coordinator makes variable nil and we lose result of a file operation
        __block NSError * coordinationError = nil;
        NSFileCoordinator * fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:document];
        [fileCoordinator coordinateWritingItemAtURL:document.fileURL
                                            options:NSFileCoordinatorWritingForDeleting
                                              error:&coordinationError
                                         byAccessor:accessor];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion != nil) {
                completion(coordinationError != nil ? coordinationError
                                             : deletetionError);
            }
        });
    });
}

- (void)makeClosedDocument:(CDBDocument * _Nonnull)document
                ubiquitous:(BOOL)ubiquitous
                completion:(CDBErrorCompletion _Nonnull)completion {
    
    if (document.isUbiquitous == ubiquitous) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }
    
    if (self.ubiquityContainerAccessible == NO) {
        if (completion != nil) {
            completion([self iCloudNotAcceessableError]);
        }
        return;
    }
    
    NSURL * destinationURL = ubiquitous ? [self ubiquityDocumentFileURLUsingLocalURL:document.fileURL]
                                        : [self localDocumentFileURLUsingUbiquityURL:document.fileURL];
    
    if ([document.fileURL isEqual:destinationURL]) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }
    
    dispatch_async(self.serialQueue, ^(void) {
        NSError * error = nil;
        [self.fileManager setUbiquitous:ubiquitous
                              itemAtURL:document.fileURL
                         destinationURL:destinationURL
                                  error:&error];
    
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion != nil) {
                completion(error);
            }
        });
    });
}

- (void)moveClosedDocument:(CDBDocument *)document
                     toURL:(NSURL *)destinationURL
                completion:(CDBErrorCompletion)completion {
    dispatch_async(self.serialQueue, ^(void) {
        
        __block NSError * copyingError = nil;
        void (^accessor)(NSURL*, NSURL*) = ^(NSURL *newURL1, NSURL *newURL2) {
            [self.fileManager moveItemAtURL:newURL1
                                      toURL:newURL2
                                      error:&copyingError];
        };
        
        __block NSError * coordinationError = nil;
        NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:document];
        [coordinator coordinateWritingItemAtURL:document.fileURL
                                        options:NSFileCoordinatorWritingForMoving
                               writingItemAtURL:destinationURL
                                        options:NSFileCoordinatorWritingForReplacing
                                          error:&coordinationError
                                     byAccessor:accessor];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion != nil) {
                completion(coordinationError != nil ? coordinationError
                                                    : copyingError);
            }
        });
    });
}

- (void)copyClosedDocument:(CDBDocument *)document
                     toURL:(NSURL *)destinationURL
                   replace:(BOOL)replace
                completion:(CDBErrorCompletion)completion {
    dispatch_async(self.serialQueue, ^(void) {
        __block NSError * copyingError = nil;
        void (^accessor)(NSURL*, NSURL*) = ^(NSURL *newURL1, NSURL *newURL2) {
            if (replace) {
                [self.fileManager removeItemAtURL:newURL2
                                            error:nil];
            }
            [self.fileManager copyItemAtURL:newURL1
                                      toURL:newURL2
                                      error:&copyingError];
        };
        
        __block NSError * coordinationError = nil;
        NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:document];
        [coordinator coordinateReadingItemAtURL:document.fileURL
                                        options:NSFileCoordinatorReadingWithoutChanges
                               writingItemAtURL:destinationURL
                                        options:NSFileCoordinatorWritingForReplacing
                                          error:&coordinationError
                                     byAccessor:accessor];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion != nil) {
                completion(coordinationError != nil ? coordinationError
                                                    : copyingError);
            }
        });
    });
}


- (CDBDocument *)documentWithAvailableFileURL:(NSURL *)fileURL
                                        error:(NSError *__autoreleasing *)error {
    BOOL directory = NO;
    BOOL exist = [self.fileManager fileExistsAtPath:fileURL.path
                                        isDirectory:&directory];
    if (exist == NO || directory) {
        *error = [self directoryUnacceptableURLErrorUsingURL:fileURL];
        return nil;
    }
    
    CDBDocument * result = [[CDBDocument alloc] initWithFileURL:fileURL];
    return result;
}

#pragma mark Synchronize documents

- (void)startSynchronizationWithCompletion:(CDBErrorCompletion)completion {
    if (self.documentsDirectoryWatchdog == nil) {
        self.documentsDirectoryWatchdog = [CDBDocument documentWithFileURL:self.ubiquityDocumentsURL
                                                                  delegate:self];
        [NSFileCoordinator addFilePresenter:self.documentsDirectoryWatchdog];
    }
    
    [self.metadataQuery setSearchScopes:@[NSMetadataQueryUbiquitousDocumentsScope]];
    [self.metadataQuery setPredicate:[self requestedFilesMetadataPredicate]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMetadataQueryDidUpdateNotification:)
                                                     name:NSMetadataQueryDidUpdateNotification
                                                   object:self.metadataQuery];
        
        [[NSNotificationCenter defaultCenter]  addObserver:self
                                                  selector:@selector(handleMetadataQueryDidFinishGatheringNotification:)
                                                      name:NSMetadataQueryDidFinishGatheringNotification
                                                    object:self.metadataQuery];
        
        BOOL startedQuery = [self.metadataQuery startQuery];
        if (startedQuery == NO) {
            NSLog(@"[CDBCloudDocuments] Failed to start metadata query");
        }
        
        if (completion != nil) {
            completion(nil);
        }
    });
}

- (void)updateFilesWithCompletion:(CDBCompletion)completion {
    __weak typeof (self) wself = self;
    [self.metadataQuery disableUpdates];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSMutableArray * documentsURLs = [NSMutableArray array];
        NSMutableArray * documentNames = [NSMutableArray array];
        
        [wself.metadataQuery enumerateResultsUsingBlock:^(NSMetadataItem * item, NSUInteger idx, BOOL *stop) {
            NSURL * fileURL = [item valueForAttribute:NSMetadataItemURLKey];

            [documentsURLs addObject:fileURL];
            [documentNames addObject:fileURL.lastPathComponent];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            wself.uniqueCloudDocumentURLs = [NSMutableSet setWithArray:documentsURLs];
            if (completion != nil) {
                completion();
            }
            [wself notifyDelegateThatUbiquitosDocumentsDidChangeQuery:self.metadataQuery];
            
            if (self.metadataQueryShouldStopAfterFinishGathering == NO) {
                [self.metadataQuery startQuery];
            }
        });
    });
}

- (void)dissmissSynchronization {
    if (self.documentsDirectoryWatchdog != nil) {
        [NSFileCoordinator removeFilePresenter:self.documentsDirectoryWatchdog];
        self.documentsDirectoryWatchdog = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_metadataQuery stopQuery];
    _metadataQuery = nil;
}

- (void)startDownloadingDocumentWithURL:(NSURL *)fileURL
                                andName:(NSString *)name {
    NSError *error;
    BOOL downloading = [self.fileManager startDownloadingUbiquitousItemAtURL:fileURL
                                                                       error:&error];
    if (downloading == NO){
        NSLog(@"[CDBCloudDocuments] Ubiquitous item with name %@ \
              \nfailed to start downloading with error: %@", name, error);
    }
}

#pragma mark Directory checking

- (void)ensureThatUbiquitousDocumentsDirectoryPresents {
    [self synchronousEnsureThatDirectoryPresentsAtURL:self.ubiquityDocumentsURL
                                            comletion:^(NSError *error) {
        if (error == nil) {
            return;
        }
        NSLog(@"[CDBCloudDocuments] could not resolve ubiquituos documents directory URL %@\
              \n failed with error: %@",
              self.ubiquityDocumentsURL, error);
        NSLog(@"[CDBCloudDocuments] ubiquituos documents directory resolved to default path");
        self.cloudPathComponent = CDBiCloudDocumentsDirectoryPathComponent;
        [self synchronousEnsureThatDirectoryPresentsAtURL:self.ubiquityDocumentsURL
                                                comletion:^(NSError *error) {
            if (error == nil) {
                return;
            }
            NSLog(@"[CDBCloudDocuments] unpredicable error \
                  \ncould not resolve default ubiquituos documents directory URL %@\
                  \n failed with error: %@",
                  self.ubiquityDocumentsURL, error);
        }];
    }];
}

- (void)synchronousEnsureThatDirectoryPresentsAtURL:(NSURL *)URL
                                          comletion:(CDBErrorCompletion)completion {
    if (URL == nil) {
        if (completion != nil) {
            completion([self directoryUnacceptableURLErrorUsingURL:URL]);
        }
        return;
    }
    
    NSError * error = nil;
    
    NSString * directoryPath = [URL path];
    BOOL isDirectory = NO;
    BOOL exist = [self.fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory];
    
    if (exist == NO) {
        [self.fileManager createDirectoryAtURL:URL
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&error];
        if (completion != nil) {
            completion(error);
        }
        return;
    }
    
    if (isDirectory) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }
    
    [self.fileManager removeItemAtPath:directoryPath
                                 error:&error];
    if (error != nil) {
        if (completion != nil) {
            completion(error);
        }
        return;
    }
    
    [self.fileManager createDirectoryAtURL:URL
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    if (completion != nil) {
        completion(error);
    }
}

#pragma mark handle documents versioning

- (NSDate *)lastProcessedDateForDocumentWithName:(NSString *)documentName {
    NSString * processedKey = [self processedDateKeyForDocumentWithName:documentName];
    if (processedKey == nil) {
        return nil;
    }
    
    NSDate * result = [[NSUserDefaults standardUserDefaults] objectForKey:processedKey];
    return result;
}

- (void)saveProcessedDate:(NSDate *)processedDate
      forDocumentWithName:(NSString *)documentName {
    if (processedDate == nil) {
        return;
    }
    
    NSString * processedKey = [self processedDateKeyForDocumentWithName:documentName];
    if (processedKey == nil) {
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:processedDate
                                              forKey:processedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)processedDateKeyForDocumentWithName:(NSString *)documentName {
    if (documentName == nil) {
        return nil;
    }
    NSString * result = [NSString stringWithFormat:CDB_Documents_Processing_Last_Date_Format, documentName];
    return result;
}

#pragma mark Ubiquitios URL

- (NSURL *)ubiquityDocumentFileURLUsingFileName:(NSString *)fileName {
    
    NSURL * result = [self.ubiquityDocumentsURL URLByAppendingPathComponent:fileName
                                                                isDirectory:NO];
    return result;
}

- (NSURL *)localDocumentFileURLUsingFileName:(NSString *)fileName {
    NSURL * result = [self.localDocumentsURL URLByAppendingPathComponent:fileName
                                                             isDirectory:NO];
    return result;
}

- (NSURL *)ubiquityDocumentFileURLUsingLocalURL:(NSURL *)localURL {
    
    NSString * relativeURLString = [self relativeURLStringFromURL:localURL
                                                     usingBaseURL:self.localDocumentsURL];
    NSURL * result = nil;
    if (relativeURLString != nil) {
        result = [self.ubiquityDocumentsURL URLByAppendingPathComponent:relativeURLString];
    } else {
        result = [self ubiquityDocumentFileURLUsingFileName:localURL.lastPathComponent];
    }
    
    return result;
}

- (NSURL *)localDocumentFileURLUsingUbiquityURL:(NSURL *)ubiquitousURL {
    NSString * relativeURLString = [self relativeURLStringFromURL:ubiquitousURL
                                                     usingBaseURL:self.ubiquityDocumentsURL];
    NSURL * result = nil;
    if (relativeURLString != nil) {
        result = [self.localDocumentsURL URLByAppendingPathComponent:relativeURLString];
    } else {
        result = [self localDocumentFileURLUsingFileName:ubiquitousURL.lastPathComponent];
    }
    
    return result;
}

- (NSString *)relativeURLStringFromURL:(NSURL *)URL
                          usingBaseURL:(NSURL *)baseURL {
    NSRange baseRange = [URL.path rangeOfString:baseURL.path];
    NSInteger relativeURLstartIndex = NSMaxRange(baseRange)+1;
    if (baseRange.location == NSNotFound
    ||  relativeURLstartIndex >= URL.path.length) {
       return nil;
    }
    
    NSString * result = [URL.path substringFromIndex:relativeURLstartIndex];
    return result;
}

#pragma mark notify delegate 

- (void)notifyDelegateThatDocumentsDidChangeState {
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([wself.delegate respondsToSelector:@selector(didChangeCloudStateOfCDBCloudDocuments:)]) {
            [wself.delegate didChangeCloudStateOfCDBCloudDocuments:wself];
        }
    });
}

- (void)notifyDelegateThatUbiquitosDocumentsDidChangeQuery:(NSMetadataQuery *)query {
    if ([self.delegate respondsToSelector:@selector(CDBCloudDocuments:didChangeMetadataQuery:)]) {
        [self.delegate CDBCloudDocuments:self
                  didChangeMetadataQuery:query];
    }
}

- (void)notifyDelegateThatDocumentsDidAutoresolveConflictInCDBDocument:(CDBDocument * _Nonnull)document {
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([wself.delegate respondsToSelector:@selector(CDBCloudDocuments: didAutoresolveConflictInCDBDocument:)]) {
            [wself.delegate CDBCloudDocuments:wself
          didAutoresolveConflictInCDBDocument:document];
        }
    });
}

- (void)notifyDelegateThatDocumentsDidChangeUbiquitosDocumentAtURL:(NSURL * _Nullable)URL {
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([wself.delegate respondsToSelector:@selector(CDBCloudDocuments: didChangeUbiquitosDocumentAtURL:)]) {
            [wself.delegate CDBCloudDocuments:wself
             didChangeUbiquitosDocumentAtURL:URL];
        }
    });
}

- (void)notifyDelegateThatDocumentsDidRemoveUbiquitosDocumentAtURL:(NSURL * _Nullable)URL {
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([wself.delegate respondsToSelector:@selector(CDBCloudDocuments: didRemoveUbiquitosDocumentAtURL:)]) {
            [wself.delegate CDBCloudDocuments:wself
             didRemoveUbiquitosDocumentAtURL:URL];
        }
    });
}

#pragma mark Logging

- (void)logMetadataQueryNotification:(NSNotification *)notification {
    if (self.verbose == NO) {
        return;
    }
    
    [notification.userInfo enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull change, NSArray *  _Nonnull metadataItems, BOOL * _Nonnull stop) {
        if (metadataItems.count == 0) {
            return;
        }
        NSLog(@"Change %@: ==============================\r", change);
        for (NSMetadataItem *metadataItem in metadataItems) {
            if ([metadataItem isKindOfClass:[NSMetadataItem class]] == NO) {
                continue;
            }
            
            [self logMetadataItem:metadataItem];
        }
    }];
}

- (void)logMetadataItem:(NSMetadataItem *)item {
    NSNumber *isUbiquitous = [item valueForAttribute:NSMetadataItemIsUbiquitousKey];
    NSNumber *hasUnresolvedConflicts = [item valueForAttribute:NSMetadataUbiquitousItemHasUnresolvedConflictsKey];
    NSString *isDownloaded = [item valueForAttribute:NSMetadataUbiquitousItemDownloadingStatusKey];
    NSNumber *isDownloading = [item valueForAttribute:NSMetadataUbiquitousItemIsDownloadingKey];
    NSNumber *isUploaded = [item valueForAttribute:NSMetadataUbiquitousItemIsUploadedKey];
    NSNumber *isUploading = [item valueForAttribute:NSMetadataUbiquitousItemIsUploadingKey];
    NSNumber *percentDownloaded = [item valueForAttribute:NSMetadataUbiquitousItemPercentDownloadedKey];
    NSNumber *percentUploaded = [item valueForAttribute:NSMetadataUbiquitousItemPercentUploadedKey];
    NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
    
    BOOL documentExists = [[NSFileManager defaultManager] fileExistsAtPath:[url path]];
    
    NSLog(@"documentExists:%i - %@\
          \r isUbiquitous:%@ hasUnresolvedConflicts:%@\
          \r isDownloaded:%@ isDownloading:%@ isUploaded:%@ isUploading:%@\
          \r %%downloaded:%@ %%uploaded:%@",
            documentExists, url,
            isUbiquitous,
            hasUnresolvedConflicts,
            isDownloaded,
            isDownloading,
            isUploaded,
            isUploading,
            percentDownloaded,
            percentUploaded);
}

@end
