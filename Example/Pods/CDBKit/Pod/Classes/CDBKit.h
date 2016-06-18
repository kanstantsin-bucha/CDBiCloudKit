

#ifndef CDBKit
#define CDBKit

/* weak and strong */

#define varUsingObjCDB(modifier, ref, obj) modifier typeof(obj) ref = obj
#define weakCDB(weakRef) varUsingObjCDB(__weak, weakRef, self)
#define weakObjCDB(weakRef, obj) varUsingObjCDB(__weak, weakRef, obj);
#define strongObjCDB(strongRef, obj) varUsingObjCDB(__strong, strongRef, obj);

/* colors */

#ifndef RGBAColor
    #define RGBAColor(r,g,b,a) [UIColor colorWithRed:r/255.0f green:g/255.0f blue:b/255.0f alpha:a]
#endif /*RGBAColor*/

#ifndef RGBColor
    #define RGBColor(r,g,b) RGBAColor(r, g, b, 1.0f)
#endif /*RGBAColor*/

/* strings */

#define NSStringFromBool(b) (b ? @"YES" : @"NO")

/* localization */

#define LSCDB(x) NSLocalizedString(@#x, nil)

/* typedefs */

typedef void (^CDBCompletion)();
typedef void (^CDBBoolCompletion) (BOOL succeeded);
typedef void (^CDBErrorCompletion) (NSError * _Nullable error);
typedef void (^CDBArrayErrorCompletion) (NSArray * _Nullable array, NSError * _Nullable error);
typedef void (^CDBDictionaryErrorCompletion) (NSDictionary * _Nullable dictionary, NSError * _Nullable error);
typedef void (^CDBObjectErrorCompletion) (id _Nullable object, NSError * _Nullable error);

/* logging */

#if DEBUG

    #define DLogCDB(...) \
    do{\
        NSLog(@"%@", [NSString stringWithFormat:__VA_ARGS__]);\
    } while(0)

#else

    #define DLogCDB(...)

#endif

    #define RLogCDB(verbose, ...) \
    do{\
        if ((verbose) == NO) continue;\
        NSLog(@"%@", [NSString stringWithFormat:__VA_ARGS__]);\
    } while(0)



#if DEBUG

    #define DLogFileCDB(...) \
    do{\
        printf("[%s:%d]", __FUNCTION__, __LINE__);\
        NSString *_S_ =  [NSString stringWithFormat:__VA_ARGS__];\
        NSLog(@"%@", _S_);\
        printf(" %s\r",[_S_ cStringUsingEncoding:NSUTF8StringEncoding]);\
    } while(0)

#else

    #define DLogCDB(...)

#endif

    #define RLogFileCDB(verbose, ...) \
    do{\
        if ((verbose) == NO) continue;\
        printf("[%s]", __FUNCTION__);\
        NSString *_S_ =  [NSString stringWithFormat:__VA_ARGS__];\
        NSLog(@"%@", _S_);\
        printf(" %s\r",[_S_ cStringUsingEncoding:NSUTF8StringEncoding]);\
    } while(0)

/* override notification */

#if DEBUG

#define DOverrideCDB(); \
    do{\
        printf("[%s:%d]", __FUNCTION__, __LINE__);\
        NSString * _S_ =  @"WARNING \
        should be overrided in a child implementation";\
        printf(" %s\r",[_S_ cStringUsingEncoding:NSUTF8StringEncoding]);\
    } while(0)

#else

    #define DOverrideCDB();

#endif

#endif /* CDBKit */