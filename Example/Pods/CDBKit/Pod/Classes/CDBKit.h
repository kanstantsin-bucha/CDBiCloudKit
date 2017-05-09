

#ifndef CDBKit
#define CDBKit

/* weakify and strongify */

#define varUsingObjCDB(modifier, ref, obj) modifier typeof(obj) ref = obj

#define weakCDB(weakRef) varUsingObjCDB(__weak, weakRef, self)
#define weakObjCDB(weakRef, obj) varUsingObjCDB(__weak, weakRef, obj);
#define strongObjCDB(strongRef, obj) varUsingObjCDB(__strong, strongRef, obj);

/* osx vs ios */

#ifdef __APPLE__
    #include "TargetConditionals.h"
    #if TARGET_OS_OSX
        // Mac
        #import <AppKit/AppKit.h>
        typedef NSColor TBColor;
        typedef NSImage TBImage;
    #elif TARGET_OS_IOS
        // iOS
        #import <UIKit/UIKit.h>
        typedef UIColor TBColor;
        typedef UIImage TBImage;
    #else
        typedef NSObject TBColor;
        typedef NSObject TBImage;
    #endif
#endif

/* colors */

TBColor * _Nullable colorWithRGBA(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);
TBColor * _Nullable colorWithHexAndAlpha(NSString * _Nonnull hex, CGFloat alpha);
#define colorWithRGB(r,g,b) colorWithRGBA(r, g, b, 1.0f)
#define colorWithHex(hex) colorWithHexAndAlpha(hex, 1.0f)

/* strings */

#define NSStringFromBool(b) (b ? @"YES" : @"NO")

/* direct localization */

#define LSD(x) NSLocalizedString(@#x, nil)

/* completions */

typedef void (^CDBCompletion)();
typedef void (^CDBBoolCompletion) (BOOL succeed);
typedef void (^CDBErrorCompletion) (NSError * _Nullable error);
typedef void (^CDBArrayErrorCompletion) (NSArray * _Nullable array, NSError * _Nullable error);
typedef void (^CDBDictionaryErrorCompletion) (NSDictionary * _Nullable dictionary, NSError * _Nullable error);
typedef void (^CDBObjectErrorCompletion) (id _Nullable object, NSError * _Nullable error);
typedef void (^CDBStringErrorCompletion) (NSString * _Nullable string, NSError * _Nullable error);
typedef void (^CDBNumberErrorCompletion) (NSNumber * _Nullable number, NSError * _Nullable error);
typedef void (^CDBDataErrorCompletion) (NSData * _Nullable number, NSError * _Nullable error);
typedef void (^CDBImageErrorCompletion) (TBImage * _Nullable number, NSError * _Nullable error);

/* derived classes interface */

#define derivedCDB(); \
    do{\
        printf("[%s:%d]", __FUNCTION__, __LINE__);\
        NSString * _S_ =  @"WARNING \
        should be implemented in a derived class";\
        printf(" %s\r",[_S_ cStringUsingEncoding: NSUTF8StringEncoding]);\
    } while(0)

#endif /* CDBKit */
