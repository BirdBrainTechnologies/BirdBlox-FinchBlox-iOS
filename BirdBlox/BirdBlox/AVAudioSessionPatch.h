//
//  AVAudioSessionPatch.h
//  BirdBlox
//
//  Created by Kristina Lauwers on 10/19/18.
//  Copyright © 2018 Birdbrain Technologies LLC. All rights reserved.
//

#ifndef AVAudioSessionPatch_h
#define AVAudioSessionPatch_h
#import <AVFoundation/AVFoundation.h>

@interface AVAudioSessionPatch: NSObject
+ (BOOL) setAudioSessionWithError:(NSError **) error;
@end


#endif /* AVAudioSessionPatch_h */



