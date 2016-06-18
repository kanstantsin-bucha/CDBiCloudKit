

#ifndef LSCDB

// localization
#define LSCDB(x) NSLocalizedString(@#x, nil)

#endif /* LSCDB */


#ifndef CDBiCloudKitConstants_h
#define CDBiCloudKitConstants_h

typedef NS_OPTIONS(NSUInteger, CDBCloudStoreState) {
    CDBCloudStoreUbiquitosAvailable = 1 << 0, // 1 - ubiquitos availble for store / 0 - local
    CDBCloudStoreUbiquitosActive = 1 << 1, // 1 - current store is ubiquitos / 0 - local
    CDBCloudStoreUbiquitosInitiated = 1 << 2 // 1 - ubiquitos initiated / 0 - waiting for initialization
};


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


typedef NS_ENUM(NSUInteger, CDBFileState) {
    CDBFileStateUndefined = 0,
    CDBFileLocal = 1,
    CDBFileUbiquitousMetadataOnly = 1, // it has metadata only
    CDBFileUbiquitousDownloaded = 2, // it downloaded to a local store
    CDBFileUbiquitousCurrent = 3 // it downloaded and has the most current state
};

#define StringFromCDBFileState(enum) (([@[\
@"CDBFileStateUndefined",\
@"CDBFileLocal",\
@"CDBFileUbiquitousMetadataOnly",\
@"CDBFileUbiquitousDownloaded",\
@"CDBFileUbiquitousCurrent",\
] objectAtIndex:(enum)]))


@class CDBDocument;


typedef void (^CDBiCloudAccessBlock) (BOOL ubiquitosConеtentAvailable);
typedef void (^CDBiCloudDocumentCompletion) (CDBDocument * _Nullable document, NSError * _Nullable error);

#endif /* CDBiCloudKitConstants_h */



