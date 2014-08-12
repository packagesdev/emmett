#import <Foundation/Foundation.h>

@interface NSDictionary (EMMutableLoad)

+ (id) mutableDictionaryWithContentsOfFile:(NSString *) inPath;

@end
