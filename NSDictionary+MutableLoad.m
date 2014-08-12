#import "NSDictionary+MutableLoad.h"

@implementation NSDictionary (EMMutableLoad)

+ (id) mutableDictionaryWithContentsOfFile:(NSString *) inFile
{
	NSData * tData;
	
	tData=[NSData dataWithContentsOfFile:inFile];
		   
	if (tData!=nil)
	{
		NSString * tErrorString;
		NSMutableDictionary * tMutableDictionary;
		NSPropertyListFormat tFormat;
		
		tMutableDictionary=(NSMutableDictionary *) [NSPropertyListSerialization propertyListFromData:tData
																		  mutabilityOption:NSPropertyListMutableContainersAndLeaves
																					format:&tFormat
																		  errorDescription:&tErrorString];
		
		if (tMutableDictionary==nil)
		{
			NSLog(@"[NSDictionary mutableDictionaryWithContentsOfFile:] : %@",tErrorString);
			
			[tErrorString release];
		}
		
		return tMutableDictionary;
	}
	
	return nil;
}

@end