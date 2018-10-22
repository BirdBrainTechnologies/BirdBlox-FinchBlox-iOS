//
//  AVAudioSessionPatch.m
//  BirdBlox
//
//  Created by Kristina Lauwers on 10/19/18.
//  Copyright © 2018 Birdbrain Technologies LLC. All rights reserved.
//

#import "AVAudioSessionPatch.h"
#import <Foundation/Foundation.h>

@implementation AVAudioSessionPatch: NSObject

+ (BOOL) setAudioSessionWithError:(NSError **) error {
    BOOL success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:error];
    if (!success && error) {
        return false;
    } else {
        return true;
    }
}
@end
