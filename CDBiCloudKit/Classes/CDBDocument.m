

#import "CDBDocument.h"


@interface CDBDocument ()

@property (strong, nonatomic, readonly) NSFileManager * fileManager;

@end


@implementation CDBDocument

@synthesize contents = _contents;

#pragma mark - Life cycle -

+ (instancetype)documentWithFileURL:(NSURL *)url
                           delegate:(id<CDBDocumentDelegate>)delegate {
    CDBDocument * document = [[self alloc] initWithFileURL:url];
    document.delegate = delegate;
    
    return document;
}

- (instancetype)initWithFileURL:(NSURL *)URL {
    if (URL.path.length == 0) {
        DLogCDB(@"FAILED create document with nil URL");
        return nil;
    }
    
    self = [super initWithFileURL:URL];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleUIDocumentStateChangedNotification:)
                                                     name:UIDocumentStateChangedNotification
                                                   object:self];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications -

- (void)handleUIDocumentStateChangedNotification:(NSNotification *)notification {
    if (self.documentState != UIDocumentStateInConflict) {
        return;
    }
    
    [self resolveConflict];
    
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([wself.delegate respondsToSelector:@selector(didAutoresolveConflictInCDBDocument:)]) {
            [wself.delegate didAutoresolveConflictInCDBDocument:wself];
        }
    });
    
}

#pragma mark - Protocols -

#pragma mark NSFilePresenter

- (void)savePresentedItemChangesWithCompletionHandler:(void (^)(NSError * __nullable errorOrNil))completionHandler {
    DLogCDB(@"%@", self.fileName);
}

- (void)accommodatePresentedItemDeletionWithCompletionHandler:(void (^)(NSError * __nullable errorOrNil))completionHandler {
    DLogCDB(@"%@", self.fileName);
}

- (void)presentedItemDidMoveToURL:(NSURL *)newURL {
    [super presentedItemDidMoveToURL:newURL];
    DLogCDB(@"%@ new URL: %@", self.fileName, newURL);
}

- (void)presentedItemDidChange {
    DLogCDB(@"%@", self.fileName);
}

#pragma mark NSFilePresenter directory

//// This don't called for now iOS 9.3 - apple registered bug
//- (void)accommodatePresentedSubitemDeletionAtURL:(NSURL *)url
//                               completionHandler:(void (^)(NSError * __nullable errorOrNil))completionHandler {
//    [super accommodatePresentedSubitemDeletionAtURL:url
//                                  completionHandler:completionHandler];
//}

//// This don't called for now iOS 9.3 - apple registered bug
//- (void)presentedSubitemDidAppearAtURL:(NSURL *)url {
//    [super presentedSubitemDidAppearAtURL:url];
//}

//// This called only from time to time for now iOS 9.3 - apple registered bug
//- (void)presentedSubitemAtURL:(NSURL *)oldURL
//                 didMoveToURL:(NSURL *)newURL {
//    NSLog(@"presentedSubitemAtURL");
//}

- (void)presentedSubitemDidChangeAtURL:(NSURL *)URL {
    DLogCDB(@"%@", self.fileName);
    if ([self.delegate respondsToSelector:@selector(CDBDocumentDirectory:didChangeSubitemAtURL:)] == NO) {
        return;
    }
    
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wself.delegate CDBDocumentDirectory:wself
                       didChangeSubitemAtURL:URL];
    });
}

#pragma mark - Protected -

#pragma mark Loading and Saving

- (NSDate *)fileModificationDate {
    NSFileVersion * currentVersion = [NSFileVersion currentVersionOfItemAtURL:self.fileURL];
    NSDate * result = currentVersion.modificationDate;
    return result;
}

- (id)contentsForType:(NSString *)typeName
                error:(NSError **)outError {
    NSData * result = self.contents;
    return result;
}

- (BOOL)loadFromContents:(id)fileContents
                  ofType:(NSString *)typeName
                   error:(NSError **)outError {
    if ([fileContents isKindOfClass:[NSData class]] == NO) {
        *outError = [self loadFromContentsOfUnsupportedTypeError];
        return NO;
    }
    
    self.contents = [[NSData alloc] initWithData:fileContents];
    
    return YES;
}

- (NSString *)localizedName {
    NSString * result = self.fileName;
    return result;
}


// removed temporary - has issue on description copy on dellocation that stub fileState methods
//- (NSString *)description {
//    NSString * result = [NSString stringWithFormat:
//                        @"[%@:<%@>] %@\
//                        \r fileURL: %@\
//                        \r ubiquitous: %@\
//                        \r documentState: %@\
//                        \r fileState: %@ %@\
//                        \r modifiedDate: %@\
//                        \r fileSize: %.2f MB",
//                        NSStringFromClass([self class]), @(self.hash), self.localizedName,
//                        self.fileURL,
//                        self.isUbiquitous ? @"YES" : @"NO",
//                        self.localizedDocumentState,
//                        StringFromCDBFileState(self.fileState), self.fileName,
//                        self.fileModificationDate,
//                        (float)[(NSData *)self.contents length]/1024.0f/1024.0f];
//    return result;
//}

#pragma mark Handling error

- (void)handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted {
    [super handleError:error userInteractionPermitted:userInteractionPermitted];
    NSLog(@"[iCloudDocumentsContainer] iCloudDocument failed with error %@", error);
}

#pragma mark - Private -

- (void)resolveConflict {
    NSLog(@"[iCloudDocumentsContainer] resolving conflicts in document %@. Newest wins", self.localizedName);
    NSError *error = nil;
    [NSFileVersion removeOtherVersionsOfItemAtURL:self.fileURL
                                            error:&error];
    if (error != nil) {
        NSLog(@"[iCloudDocumentsContainer] failed removing other document versions: %@",
              error.localizedFailureReason);
        return;
    }
    NSLog(@"[iCloudDocumentsContainer] resolved conflicts in document %@",
          self.localizedName);
    NSFileVersion * currentVersion = [NSFileVersion currentVersionOfItemAtURL:self.fileURL];
    currentVersion.resolved = YES;
}

#pragma mark - Property -

#pragma mark Setter

- (void)setContents:(NSData *)contents {
    [self.undoManager setActionName:@"Contents changed"];
    [self.undoManager registerUndoWithTarget:self
                                    selector:@selector(setContents:)
                                      object:self.contents];
    _contents = [contents copy];
}

#pragma mark Getter

- (NSError *)loadFromContentsOfUnsupportedTypeError {
    NSDictionary * userInfo = @{NSLocalizedDescriptionKey: @"Unsupported contents type"};
    NSError * result = [NSError errorWithDomain:NSStringFromClass([self class])
                                           code:0
                                       userInfo:userInfo];
    return result;
}

- (NSError *)iCloudDocumentNotOperableError {
    NSString * errorDescription = [NSString stringWithFormat:@"Could not process operation, iCloud file state: %@\
                                   \n documentState: %@)",
                                    StringFromCDBFileState(self.fileState),
                                    self.localizedDocumentState];
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
                                           code:0
                                       userInfo:userInfo];
    return result;
}

- (NSString *)localizedDocumentState {
    NSString * result = @"|";
    
    if ((self.documentState & UIDocumentStateNormal) != 0) {
        result = [result stringByAppendingString:@" normal |"];
    }
    if ((self.documentState & UIDocumentStateClosed) != 0) {
        result = [result stringByAppendingString:@" closed |"];
    } else {
        // deleted file still looks like not closed ;]
        if (self.deleted == NO) {
            result = [result stringByAppendingString:@" opened |"];
        } else {
            result = [result stringByAppendingString:@" deleted |"];
        }
    }
    if ((self.documentState & UIDocumentStateInConflict) != 0) {
        result = [result stringByAppendingString:@" in conflict |"];
    }
    if ((self.documentState & UIDocumentStateSavingError) != 0) {
        result = [result stringByAppendingString:@" saving error |"];
    }
    if ((self.documentState & UIDocumentStateEditingDisabled) != 0) {
        result = [result stringByAppendingString:@" editind disabled |"];
    }
    
    return result;
}

- (CDBFileState)fileState {
    if (self.deleted) {
        return CDBFileStateUndefined;
    }

    if (self.isUbiquitous == NO) {
        return CDBFileLocal;
    }
    
    CDBFileState result = CDBFileStateUndefined;
    
    NSString * documentState;
    [self.fileURL getResourceValue:&documentState
                            forKey:NSURLUbiquitousItemDownloadingStatusKey
                             error:nil];
    
    if ([documentState isEqualToString:NSURLUbiquitousItemDownloadingStatusDownloaded]) {
        result = CDBFileUbiquitousDownloaded;
    }
    
    if ([documentState isEqualToString:NSURLUbiquitousItemDownloadingStatusCurrent]) {
        result = CDBFileUbiquitousCurrent;
    }
    
    if ([documentState isEqualToString:NSURLUbiquitousItemDownloadingStatusNotDownloaded]) {
        result = CDBFileUbiquitousMetadataOnly;
    }
    
    return result;
}

- (BOOL)isUbiquitous {
    BOOL result = [self.fileManager isUbiquitousItemAtURL:self.fileURL];
    return result;
}

- (BOOL)isDeleted {
    BOOL result = self.fileName.length == 0;
    return result;
}

- (BOOL)isClosed {
    BOOL result = (self.documentState & UIDocumentStateClosed) != 0;
    return result;
}

- (NSString *)fileName {
    NSString * result = [self.fileURL lastPathComponent];
    return result;
}

- (NSFileManager *)fileManager {
    NSFileManager * result = [NSFileManager new];
    return result;
}

#pragma mark Lazy loading

- (NSData *)contents {
    if (_contents == nil) {
        _contents = [NSData new];
    }
    return _contents;
}

@end
