//
//  ViewController.m
//  VideoHandler
//
//  Created by 刘士伟 on 2017/3/27.
//  Copyright © 2017年 刘士伟. All rights reserved.
//

#import "ViewController.h"
#import "ReverseManager.h"

#define kVideoPath NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
   
}

- (IBAction)reverseVideo:(id)sender {
    
    NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"morning" ofType:@"mp4"];
    
    //逆序视频路径
    NSString *outputPath = [kVideoPath stringByAppendingPathComponent:@"morningReverse.mp4"];
    
    ReverseManager *reverseManager = [ReverseManager defaultManager];
    
    [reverseManager reverseVideoWithPath:videoPath outputPath:outputPath Complete:^{
        
        NSLog(@"%@",outputPath);
        
    }];
    
    
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
