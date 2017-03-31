//
//  ReverseManager.h
//  VideoHandler
//
//  Created by 刘士伟 on 2017/3/30.
//  Copyright © 2017年 刘士伟. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ReverseManager : NSObject

+(instancetype)defaultManager;


-(void)reverseVideoWithPath:(NSString *)path outputPath:(NSString *)outputPath Complete:(void(^)())complete;

@end
