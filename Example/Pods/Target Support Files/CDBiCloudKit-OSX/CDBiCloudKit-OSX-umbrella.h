#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "CDBCloudConnection.h"
#import "CDBCloudDocuments.h"
#import "CDBCloudStore.h"
#import "CDBDocument.h"
#import "CDBiCloudKit.h"
#import "CDBiCloudKitConstants.h"

FOUNDATION_EXPORT double CDBiCloudKitVersionNumber;
FOUNDATION_EXPORT const unsigned char CDBiCloudKitVersionString[];

