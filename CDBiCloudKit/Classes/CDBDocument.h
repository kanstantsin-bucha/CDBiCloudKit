
#if __has_feature(objc_modules)
    @import Foundation;
#else
    #import <Foundation/Foundation.h>
#endif


#import "CDBiCloudKitConstants.h"
#import <CDBKit/CDBKit.h>

#ifdef __APPLE__
    #include "TargetConditionals.h"
    #if TARGET_OS_OSX
        // Mac
        #import <AppKit/AppKit.h>
        typedef NSDocument BaseDocument;
    #elif TARGET_OS_IOS
        // iOS
        #import <UIKit/UIKit.h>
        typedef UIDocument BaseDocument;
    #else
        typedef NSObject BaseDocument;
    #endif
#endif


@class CDBDocument;


@protocol CDBDocumentDelegate <NSObject>

@optional
- (void)didAutoresolveConflictInCDBDocument:(CDBDocument * _Nonnull)document;

- (void)CDBDocumentDirectory:(CDBDocument * _Nonnull)document
       didChangeSubitemAtURL:(NSURL * _Nullable)URL;

@end


@interface CDBDocument : BaseDocument

@property (strong, nonatomic, nullable) NSData * contents;
@property (assign, nonatomic) CDBFileState fileState;
@property (copy, nonatomic, readonly, nonnull) NSString * localizedDocumentState;
@property (copy, nonatomic, readonly, nonnull) NSString * fileName;
@property (weak, nonatomic, nullable) id<CDBDocumentDelegate> delegate;

/**
 Returns YES if it is iCloud document
 **/
@property (assign, nonatomic, readonly, getter=isUbiquitous) BOOL ubiquitous;

/**
 Returns YES if document is closed
 Be aware. SDK rarely calls handler of [ closeWithCompletionHandler:] or
                                       [ openWithCompletionHandler:]
 if document already closed (opened)
 It is unpredictable behaviour and you better just check state before use it
**/
@property (assign, nonatomic, readonly, getter=isClosed) BOOL closed;

/**
 Returns YES for deleted documents
 Behaviour based on empty fileURL (CBDDocumentsContainer set it for deleted documents)
**/
@property (assign, nonatomic, readonly, getter=isDeleted) BOOL deleted;


+ (instancetype _Nullable)documentWithFileURL:(NSURL * _Nonnull)url
                                     delegate:(id<CDBDocumentDelegate> _Nullable)delegate;
#if TARGET_OS_OSX
- (void)closeWithCompletionHandler:(void (^ __nullable)(BOOL success))completionHandler;
#endif

- (NSError * _Nonnull)iCloudDocumentNotOperableError;

@end
