//
//  CDBViewController.m
//  CDBiCloudKit
//
//  Created by yocaminobien on 06/18/2016.
//  Copyright (c) 2016 yocaminobien. All rights reserved.
//

#import "CDBViewController.h"
#import <CDBiCloudKit/CDBiCloudKit.h>

@interface CDBViewController ()

@property (strong, nonatomic) CDBCloudConnection * cloud;

@end

@implementation CDBViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.cloud = [CDBCloudConnection sharedInstance];
    
    [self.cloud initiateWithUbiquityDesired: YES
                   usingContainerIdentifier: @"icloud.same.id"
                     documentsPathComponent: nil
                         appGroupIdentifier: @"group.same.id"
                                  storeName: @"coreData"
                              storeModelURL: [NSURL new]
                                   delegete: nil];
    
    self.cloud.documents.appGroupsActive = NO;
    self.cloud.documents.metadataQueryShouldStopAfterFinishGathering = YES;;

    
    [self.cloud.store setAppGroupsActive: YES];


	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
