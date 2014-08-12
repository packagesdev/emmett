/*
 Copyright (c) 2012, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "EMUtility.h"

#import "NSDictionary+MutableLoad.h"

#include <CoreServices/CoreServices.h>

#include <signal.h>

#include <time.h>

#import "RegexKitLite.h"

#include "usage.h"

NSString * const EM_DOCK_PREFERENCES_RELATIVE_FILE_PATH=@"Library/Preferences/com.apple.dock.plist";

NSString * const EM_PERSISTENT_APPS_SECTION=@"persistent-apps";

NSString * const EM_PERSISTENT_OTHERS_SECTION=@"persistent-others";

NSString * const EM_GUID_KEY=@"GUID";

NSString * const EM_TILE_DATA_KEY=@"tile-data";

NSString * const EM_DOCK_EXTRA_KEY=@"dock-extra";

NSString * const EM_FILE_DATA_KEY=@"file-data";

NSString * const EM_FILE_LABEL_KEY=@"file-label";

NSString * const EM_FILE_MOD_DATE_KEY=@"file-mod-date";

NSString * const EM_FILE_TYPE_KEY=@"file-type";

NSString * const EM_PARENT_MOD_DATE_KEY=@"parent-mod-date";

NSString * const EM_BUNDLE_IDENTIFER_KEY=@"bundle-identifier";

NSString * const EM_CFURLALIASDATA_KEY=@"_CFURLAliasData";

NSString * const EM_CFURLSTRING_KEY=@"_CFURLString";

NSString * const EM_CFURLSTRINGTYPE_KEY=@"_CFURLStringType";

#define EM_CFURLSTRINGTYPE_ABSOLUTE_PATH	0
#define EM_CFURLSTRINGTYPE_LOCALHOST_PATH	15		// Used in Lion and later

NSString * const EM_TILE_TYPE_KEY=@"tile-type";

NSString * const EM_TILE_TYPE_FILE=@"file-tile";

NSString * const EM_TILE_TYPE_DIRECTORY=@"directory-tile";

NSString * const APPLE_DOCK_BUNDLE_IDENTIFIER=@"com.apple.dock";

NSString * const LION_DOCK_VERSION=@"1.8";

@implementation EMUtility

+ (pid_t) findDockPID
{
	struct ProcessSerialNumber tProcessSerialNumber = { 0, 0 };
	
	while (GetNextProcess(&tProcessSerialNumber) == noErr)
	{
		NSDictionary * tProcessDictionary;
		
		tProcessDictionary=(NSDictionary *) ProcessInformationCopyDictionary(&tProcessSerialNumber, kProcessDictionaryIncludeAllInformationMask);
		
		if (tProcessDictionary!=nil)
		{
			NSString * tProcessBundleIdentifier;
			
			tProcessBundleIdentifier=[tProcessDictionary objectForKey:(NSString *) kCFBundleIdentifierKey];
			
			[tProcessDictionary release];
			
			if ([tProcessBundleIdentifier isEqualToString:APPLE_DOCK_BUNDLE_IDENTIFIER]==YES)
			{
				pid_t tDockPID;
				OSStatus tStatus;
				
				tStatus=GetProcessPID(&tProcessSerialNumber,&tDockPID);
				
				if (tStatus==noErr)
				{
					return tDockPID;
				}
			}
		}
	}
	
	return 0;
}

+ (BOOL) sendQuitEventToDock
{
	OSType tDockSignature='dock';
	NSAppleEventDescriptor * tApplicationDescriptor;
	
	tApplicationDescriptor=[NSAppleEventDescriptor descriptorWithDescriptorType:typeApplSignature
																		  bytes:&tDockSignature
																		 length:sizeof(OSType)];
	
	if (tApplicationDescriptor!=nil)
	{
		NSAppleEventDescriptor * tQuitEvent;
		
		tQuitEvent=[NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass
															eventID:kAEQuitApplication
												   targetDescriptor:tApplicationDescriptor
														   returnID:kAutoGenerateReturnID
													  transactionID:kAnyTransactionID];
		
		if (tQuitEvent!=nil)
		{
			AppleEvent * tAppleEventPtr;
			
			tAppleEventPtr=(AEDesc *) [tQuitEvent aeDesc];
	
			if (tAppleEventPtr!=NULL)
			{
				OSStatus tStatus;
				
				tStatus=AESendMessage(tAppleEventPtr, NULL, kAENoReply,kAEDefaultTimeout);
				
				return (tStatus==noErr);
			}
		}
	}
	
	return NO;
}

+ (BOOL) quitAndStopDockProcess
{
	pid_t tDockPID;
	
	tDockPID=[EMUtility findDockPID];
	
	if (tDockPID>0)
	{
		pid_t tNewDockPID;
		NSUInteger tAttemptsCount=0;
		const struct timespec tTimeSpec={0,500000000};
		
#define MAX_ATTEMPT_COUNT		15
		
		// Porperly quit the Dock
		
		[EMUtility sendQuitEventToDock];
		
		// Wait for the Dock to come back
		
		do
		{
			NSAutoreleasePool * tAutoreleasePool;
			
			tAutoreleasePool=[[NSAutoreleasePool alloc] init];
			
			tNewDockPID=[EMUtility findDockPID];
			
			if (tNewDockPID==-1)
			{
				tAttemptsCount+=1;
				
				nanosleep(&tTimeSpec, NULL);
			}
			
			[tAutoreleasePool drain];
		}
		while ((tNewDockPID==0 || tNewDockPID==tDockPID) && tAttemptsCount<MAX_ATTEMPT_COUNT);
		
		if (tAttemptsCount<MAX_ATTEMPT_COUNT)
		{
			// Stop the Process
			
			if (kill(tNewDockPID,SIGSTOP)==0)
			{
				return YES;
			}
			else
			{
				(void)fprintf(stderr, "%s\n","emmett: unable to stop the Dock process");
				
				exit(1);
			}
		}
		else
		{
			(void)fprintf(stderr, "%s\n","emmett: Dock did not relaunch");
			
			exit(1);
		}
	}
	else
	{
		return YES;
	}

	return NO;
}

+ (BOOL) resumeAndKillDockProcess
{
	pid_t tDockPID;
	
	tDockPID=[EMUtility findDockPID];
	
	if (tDockPID>0)
	{
		// Resume
		
		if (kill(tDockPID,SIGCONT)==0)
		{
			// Kill
			
			if (kill(tDockPID,SIGHUP)==0)
			{
				return YES;
			}
			else
			{
				(void)fprintf(stderr, "%s\n","emmett: unable to kill the Dock process");
				
				exit(1);
			}
		}
		else
		{
			(void)fprintf(stderr, "%s\n","emmett: unable to resume the Dock process");
			
			exit(1);
		}
	}
	
	return NO;
}

/*+ (NSNumber *) computeGUIDWithDictionary:(NSDictionary *) inDictionary
{
	int tMaxGUID=INT_MIN;
	NSArray * tArray;
	
	// Persistent apps
	
	tArray=(NSArray *) CFPreferencesCopyAppValue((CFStringRef) EM_PERSISTENT_APPS_SECTION, (CFStringRef) APPLE_DOCK_BUNDLE_IDENTIFIER);
	
	for(NSDictionary * tExistingTileDictionary in tArray)
	{
		NSNumber * tNumber;
		
		tNumber=[tExistingTileDictionary objectForKey:EM_GUID_KEY];
		
		if (tNumber!=nil)
		{
			int tValue;
		
			tValue=[tNumber intValue];
		
			if (tValue>tMaxGUID)
			{
				tMaxGUID=tValue;
			}
		}
	}
	
	[tArray release];
	
	// Persistent others
	
	tArray=(NSArray *) CFPreferencesCopyAppValue((CFStringRef) EM_PERSISTENT_OTHERS_SECTION, (CFStringRef) APPLE_DOCK_BUNDLE_IDENTIFIER);
	
	for(NSDictionary * tExistingTileDictionary in tArray)
	{
		NSNumber * tNumber;
		
		tNumber=[tExistingTileDictionary objectForKey:EM_GUID_KEY];
		
		if (tNumber!=nil)
		{
			int tValue;
			
			tValue=[tNumber intValue];
			
			if (tValue>tMaxGUID)
			{
				tMaxGUID=tValue;
			}
		}
	}
	
	[tArray release];
	
	return [NSNumber numberWithInt:tMaxGUID+1];
}*/

+ (BOOL) addTileToSection:(NSString *) inSection withItemAtPath:(NSString *) inPath options:(NSUInteger) inOptions
{
	if (inSection!=nil && inPath!=nil)
	{
		BOOL isDirectory=NO;
		NSMutableArray * tMutableSectionArray=nil;
		NSArray * tSectionArray;
		
		tSectionArray=(NSArray *) CFPreferencesCopyAppValue((CFStringRef) inSection, (CFStringRef) APPLE_DOCK_BUNDLE_IDENTIFIER);
		
		if (tSectionArray!=nil)
		{
			tMutableSectionArray=[[tSectionArray mutableCopy] autorelease];
			
			[tSectionArray release];
		}
		
		if (tMutableSectionArray!=nil)
		{
			NSString * tItemBundleIdentifier=nil;
			BOOL isPersistentApp=NO;
			NSMutableIndexSet * tMutableIndexSet;
			NSUInteger tIndex=0;
			NSMutableDictionary * tNewTileDictionary;
			NSBundle * tNewBundle=nil;
			NSFileManager * tFileManager;
			
			tFileManager=[NSFileManager defaultManager];
			
			isPersistentApp=[inSection isEqualToString:EM_PERSISTENT_APPS_SECTION];
			
			if (isPersistentApp==YES)
			{
				tNewBundle=[NSBundle bundleWithPath:inPath];
				
				tItemBundleIdentifier=[tNewBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
			}
			
			tMutableIndexSet=[NSMutableIndexSet indexSet];
			
			for(NSDictionary * tExistingTileDictionary in tMutableSectionArray)
			{
				NSString * tString;
				
				tString=[tExistingTileDictionary objectForKey:EM_TILE_TYPE_KEY];
				
				if ([tString isEqualToString:EM_TILE_TYPE_FILE]==YES ||
					[tString isEqualToString:EM_TILE_TYPE_DIRECTORY]==YES)
				{
					NSDictionary * tTileDataDictionary;
					
					tTileDataDictionary=[tExistingTileDictionary objectForKey:EM_TILE_DATA_KEY];
					
					if (tTileDataDictionary!=nil)
					{
						NSDictionary * tFileDataDictionary;
						
						tFileDataDictionary=[tTileDataDictionary objectForKey:EM_FILE_DATA_KEY];
						
						if (tFileDataDictionary!=nil)
						{
							int tStringType;
							NSString * tPath;
							
							tStringType=[[tFileDataDictionary objectForKey:EM_CFURLSTRINGTYPE_KEY] intValue];
							
							tPath=[tFileDataDictionary objectForKey:EM_CFURLSTRING_KEY];
							
							if (EM_CFURLSTRINGTYPE_LOCALHOST_PATH==tStringType)
							{
								// Lion and later
								
								tPath=[[NSURL URLWithString:tPath] path];
							}
							
							if (tPath!=nil)
							{
								if ([tPath caseInsensitiveCompare:inPath]==NSOrderedSame)
								{
									// The item is already there
									
									return YES;
								}
								else
								{
									if (([tPath hasSuffix:@"/"] ^ [inPath hasSuffix:@"/"])==YES)
									{
										if (([tPath hasSuffix:@"/"]==YES && [tPath caseInsensitiveCompare:[inPath stringByAppendingString:@"/"]]==NSOrderedSame) ||
											([inPath hasSuffix:@"/"]==YES && [inPath caseInsensitiveCompare:[tPath stringByAppendingString:@"/"]]==NSOrderedSame))
										{
											[tMutableIndexSet addIndex:tIndex];
										}
									}
									
									if ((inOptions & kRemoveDuplicates)==kRemoveDuplicates && tItemBundleIdentifier!=nil)
									{
										NSString * tBundleIdentifier;
										NSBundle * tBundle;
			
										tBundle=[NSBundle bundleWithPath:tPath];
										
										tBundleIdentifier=[tBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
										
										if ([tBundleIdentifier isEqualToString:tItemBundleIdentifier]==YES)
										{
											[tMutableIndexSet addIndex:tIndex];
										}
									}
								}
							}

						}
					}
				}
				
				tIndex++;
			}
			
			if ([tMutableIndexSet count]>0)
			{
				[tMutableSectionArray removeObjectsAtIndexes:tMutableIndexSet];
			}
			
			// Add the new item
			
			// Don't set GUID as this can lead to cache issues (until I figure out how GUID is computed)
			
			tNewTileDictionary=[NSMutableDictionary dictionary];
			
			if (tNewTileDictionary!=nil)
			{
				NSMutableDictionary * tNewTileDataDictionary;
				NSString * tFileLabel;
				NSString * tTileType=EM_TILE_TYPE_FILE;
				
				tFileLabel=[[inPath lastPathComponent] stringByDeletingPathExtension];
				
				// tile-data
				
				tNewTileDataDictionary=[NSMutableDictionary dictionaryWithObject:tFileLabel forKey:EM_FILE_LABEL_KEY];
				
				if (tNewTileDataDictionary!=nil)
				{
					NSMutableDictionary * tNewFileDataDictionary=nil;
					NSURL * tURL;
					FSRef tFSRef;
					
					if (isPersistentApp==YES && tNewBundle==nil)
					{
						NSString * tDockTilePluginPath;
						
						// dock-extra
						
						tDockTilePluginPath=[tNewBundle objectForInfoDictionaryKey:@"NSDockTilePlugIn"];
						
						if ([tDockTilePluginPath isKindOfClass:[NSString class]]==YES && ([tDockTilePluginPath length]>0))
						{
							[tNewTileDataDictionary setObject:[NSNumber numberWithBool:YES] forKey:EM_DOCK_EXTRA_KEY];
						}
						
						// bundle-identifier (Lion or later)
						
						if (tItemBundleIdentifier!=nil)
						{
							[tNewTileDataDictionary setObject:tItemBundleIdentifier forKey:EM_BUNDLE_IDENTIFER_KEY];
						}
					}
					
					// file-mod-date & parent-mod-date
					
					tURL=[NSURL fileURLWithPath:inPath];
					
					if (CFURLGetFSRef((CFURLRef) tURL, &tFSRef)==TRUE)
					{
						FSCatalogInfo tCatalogInfo;
						FSRef tParentRef;
						OSErr tErr;
						
						tErr=FSGetCatalogInfo(&tFSRef, kFSCatInfoContentMod, &tCatalogInfo, NULL, NULL, &tParentRef);
						
						if (tErr==noErr)
						{
							OSStatus tStatus;
							CFAbsoluteTime tAbsoluteTime;
							
							tStatus=UCConvertUTCDateTimeToCFAbsoluteTime(&tCatalogInfo.contentModDate,&tAbsoluteTime);
							
							if (tStatus==0)
							{
								[tNewTileDataDictionary setObject:[NSNumber numberWithLong:(long) tAbsoluteTime] forKey:EM_FILE_MOD_DATE_KEY];
								
								tErr=FSGetCatalogInfo(&tParentRef, kFSCatInfoContentMod, &tCatalogInfo, NULL, NULL, NULL);
								
								if (tErr==noErr)
								{
									OSStatus tStatus;
									CFAbsoluteTime tAbsoluteTime;
									
									tStatus=UCConvertUTCDateTimeToCFAbsoluteTime(&tCatalogInfo.contentModDate,&tAbsoluteTime);
									
									if (tStatus==0)
									{
										[tNewTileDataDictionary setObject:[NSNumber numberWithLong:(long) tAbsoluteTime] forKey:EM_PARENT_MOD_DATE_KEY];
									}
								}
								else
								{
									// A COMPLETER
								}
							}
							else
							{
								// A COMPLETER
								
								// I doubt an error can occur here
							}										
						}
						else
						{
							// A COMPLETER
						}
					}
					else
					{
						if ([tFileManager fileExistsAtPath:inPath]==NO)
						{
							(void)fprintf(stderr, "%s: No such file or directory\n",[inPath fileSystemRepresentation]);
							
							return NO;
						}
					}
					
					// file-type
					
					if (isPersistentApp==YES)
					{
						[tNewTileDataDictionary setObject:[NSNumber numberWithInt:(int) 41] forKey:EM_FILE_TYPE_KEY];
					}
					else
					{
						// A COMPLETER
					}
					
					// file-data
					
					tNewFileDataDictionary=[NSMutableDictionary dictionary];
					
					if (tNewFileDataDictionary!=nil)
					{
						OSErr tErr;
						AliasHandle tHandle;
						NSString * tDockVersion;
						
						tDockVersion=[[NSBundle bundleWithPath:@"/System/Library/CoreServices/Dock.app"] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
						
						// _CFURLString
						
						if ([tDockVersion compare:LION_DOCK_VERSION options:NSNumericSearch]==NSOrderedAscending)
						{
							[tNewFileDataDictionary setObject:inPath forKey:EM_CFURLSTRING_KEY];
							
							[tNewFileDataDictionary setObject:[NSNumber numberWithInt:EM_CFURLSTRINGTYPE_ABSOLUTE_PATH] forKey:EM_CFURLSTRINGTYPE_KEY];
						}
						else
						{
							[tNewFileDataDictionary setObject:[[NSURL fileURLWithPath:inPath] absoluteString] forKey:EM_CFURLSTRING_KEY];
							
							[tNewFileDataDictionary setObject:[NSNumber numberWithInt:EM_CFURLSTRINGTYPE_LOCALHOST_PATH] forKey:EM_CFURLSTRINGTYPE_KEY];
						}
						
						// _CFURLAliasData
						
						tErr=FSNewAlias(NULL,&tFSRef,&tHandle);
						
						if (tErr==noErr)
						{
							NSData * tData;
							
							tData=[NSData dataWithBytes:(*tHandle) length:GetHandleSize((Handle) tHandle)];
							
							if (tData!=nil)
							{
								[tNewFileDataDictionary setObject:tData forKey:EM_CFURLALIASDATA_KEY];
							}
							else
							{
								(void)fprintf(stderr, "%s\n","emmett: memory too low to run operation");
							}
							
							DisposeHandle((Handle) tHandle);
						}
						else
						{
							(void)fprintf(stderr, "%s\n","emmett: memory too low to run operation");
						}

						[tNewTileDataDictionary setObject:tNewFileDataDictionary forKey:EM_FILE_DATA_KEY]; 
					}
					
					[tNewTileDictionary setObject:tNewTileDataDictionary forKey:EM_TILE_DATA_KEY];
				}
				
				// tile-type
				
				if (isPersistentApp==NO)
				{
					if ([tFileManager fileExistsAtPath:inPath isDirectory:&isDirectory]==YES && isDirectory==YES)
					{
						tTileType=EM_TILE_TYPE_DIRECTORY;
					}
				}
				
				[tNewTileDictionary setObject:tTileType forKey:EM_TILE_TYPE_KEY];
				
				
				[tMutableSectionArray addObject:tNewTileDictionary];
				
				CFPreferencesSetAppValue((CFStringRef) inSection, (CFPropertyListRef) tMutableSectionArray, (CFStringRef) APPLE_DOCK_BUNDLE_IDENTIFIER);
				
				CFPreferencesAppSynchronize((CFStringRef) APPLE_DOCK_BUNDLE_IDENTIFIER);
				
				return YES;
			}
		}
		else
		{
			// Missing section
			
			(void)fprintf(stderr, "emmett: missing section \"%s\"\n",[inSection UTF8String]);
		}
	}
	
	return NO;
}

+ (BOOL) addTileWithItemAtPath:(NSString *) inPath options:(NSUInteger) inOptions
{
	if ((inOptions & kBundleIdentifier)==kBundleIdentifier)
	{
		usage_add();
	}
	else
	{
		if (inPath!=nil)
		{
			// Check that it's an absolute path
			
			if ([inPath characterAtIndex:0]=='/')
			{
				NSString * tExtension;
				
				tExtension=[inPath pathExtension];
				
				if (tExtension!=nil && [tExtension caseInsensitiveCompare:@"app"]==NSOrderedSame)
				{
					// Add to persistent app
				
					return [EMUtility addTileToSection:EM_PERSISTENT_APPS_SECTION withItemAtPath:inPath options:inOptions];
				}
				else
				{
					// Add to persistent others
					
					return [EMUtility addTileToSection:EM_PERSISTENT_OTHERS_SECTION withItemAtPath:inPath options:inOptions];
				}
			}
			else
			{
				{
					// Error: Absolute path required
					
					(void)fprintf(stderr, "%s\n","emmett: add: absolute file or folder path");
				}
			}
		}
	}
	
	return NO;
}

+ (BOOL) removeTiteWithItemAtPath:(NSString *) inPath comparing:(NSUInteger) inComparisonType options:(NSUInteger) inOptions
{
	if (inPath!=nil)
	{
		NSArray * tPersistentDomainsArray;

		if (inComparisonType==kBundleIdentifierComparison)
		{
			// We only need to look the persistent-apps
			
			tPersistentDomainsArray=[NSArray arrayWithObject:EM_PERSISTENT_APPS_SECTION];
		}
		else
		{
			tPersistentDomainsArray=[NSArray arrayWithObjects:EM_PERSISTENT_APPS_SECTION,EM_PERSISTENT_OTHERS_SECTION,nil];
		}
		
		for(NSString * tPersistentDomainName in tPersistentDomainsArray)
		{
			NSMutableArray * tMutableSectionArray=nil;
			NSArray * tSectionArray;
			
			tSectionArray=(NSArray *) CFPreferencesCopyAppValue((CFStringRef) tPersistentDomainName, (CFStringRef) APPLE_DOCK_BUNDLE_IDENTIFIER);
			
			if (tSectionArray!=nil)
			{
				tMutableSectionArray=[tSectionArray mutableCopy];
				
				[tSectionArray release];
			}
			
			if (tMutableSectionArray!=nil)
			{
				NSMutableIndexSet * tMutableIndexSet;
				NSUInteger tIndex=0;
				
				tMutableIndexSet=[NSMutableIndexSet indexSet];
				
				for(NSDictionary * tExistingTileDictionary in tMutableSectionArray)
				{
					NSString * tString;
					
					tString=[tExistingTileDictionary objectForKey:EM_TILE_TYPE_KEY];
					
					if ([tString isEqualToString:EM_TILE_TYPE_FILE]==YES ||
						[tString isEqualToString:EM_TILE_TYPE_DIRECTORY]==YES)
					{
						NSDictionary * tTileDataDictionary;
						
						tTileDataDictionary=[tExistingTileDictionary objectForKey:EM_TILE_DATA_KEY];
						
						if (tTileDataDictionary!=nil)
						{
							NSString * tFileLabel;
							NSDictionary * tFileDataDictionary;
							NSError * tError=nil;

							switch(inComparisonType)
							{
								case kPathComparison:
								case kBundleIdentifierComparison:
									
									tFileDataDictionary=[tTileDataDictionary objectForKey:EM_FILE_DATA_KEY];
									
									if (tFileDataDictionary!=nil)
									{
										int tStringType;
										NSString * tPath;
										
										tStringType=[[tFileDataDictionary objectForKey:EM_CFURLSTRINGTYPE_KEY] intValue];
										
										tPath=[tFileDataDictionary objectForKey:EM_CFURLSTRING_KEY];
										
										if (EM_CFURLSTRINGTYPE_LOCALHOST_PATH==tStringType)
										{
											// Lion and later
											
											tPath=[[NSURL URLWithString:tPath] path];
										}
										
										if (tPath!=nil)
										{
											if (inComparisonType==kPathComparison)
											{
												// Path
												
												if ((inOptions & kRegularExpression)==kRegularExpression)
												{
													if ([tPath isMatchedByRegex:inPath options:RKLNoOptions inRange:((NSRange){0, NSUIntegerMax}) error:&tError]==YES)
													{
														[tMutableIndexSet addIndex:tIndex];
													}
												}
												else
												{
													if ([tPath caseInsensitiveCompare:inPath]==NSOrderedSame)
													{
														[tMutableIndexSet addIndex:tIndex];
													}
													else
													{
														if (([tPath hasSuffix:@"/"] ^ [inPath hasSuffix:@"/"])==YES)
														{
															if (([tPath hasSuffix:@"/"]==YES && [tPath caseInsensitiveCompare:[inPath stringByAppendingString:@"/"]]==NSOrderedSame) ||
																([inPath hasSuffix:@"/"]==YES && [inPath caseInsensitiveCompare:[tPath stringByAppendingString:@"/"]]==NSOrderedSame))
															{
																[tMutableIndexSet addIndex:tIndex];
															}
														}
													}
												}
											}
											else
											{
												// Bundle Identifier
												
												NSString * tBundleIdentifier;
												
												tBundleIdentifier=[tTileDataDictionary objectForKey:EM_BUNDLE_IDENTIFER_KEY];
												
												if (tBundleIdentifier==nil)
												{
													NSBundle * tBundle;
												
													tBundle=[NSBundle bundleWithPath:tPath];
												
													tBundleIdentifier=[tBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
												}
												
												if ((inOptions & kRegularExpression)==kRegularExpression)
												{
													if ([tBundleIdentifier isMatchedByRegex:inPath options:RKLNoOptions inRange:((NSRange){0, NSUIntegerMax}) error:&tError]==YES)
													{
														[tMutableIndexSet addIndex:tIndex];
													}
												}
												else
												{
													if ([tBundleIdentifier isEqualToString:inPath]==YES)
													{
														[tMutableIndexSet addIndex:tIndex];
													}
												}
											}
										}
									}
									
									break;
									
								case kNameComparison:
									
									tFileLabel=[tTileDataDictionary objectForKey:EM_FILE_LABEL_KEY];
									
									if ([tFileLabel length]>0)
									{
										if ((inOptions & kRegularExpression)==kRegularExpression)
										{
											if ([tFileLabel isMatchedByRegex:inPath options:RKLNoOptions inRange:((NSRange){0, NSUIntegerMax}) error:&tError]==YES)
											{
												[tMutableIndexSet addIndex:tIndex];
											}
										}
										else
										{
											if ([tFileLabel isEqualToString:inPath]==YES)
											{
												[tMutableIndexSet addIndex:tIndex];
											}
										}
									}
									
									break;
							}
						}
					}
					
					tIndex++;
				}
				
				if ([tMutableIndexSet count]>0)
				{
					[tMutableSectionArray removeObjectsAtIndexes:tMutableIndexSet];
				}
				
				CFPreferencesSetAppValue((CFStringRef) tPersistentDomainName, (CFPropertyListRef) tMutableSectionArray, (CFStringRef) APPLE_DOCK_BUNDLE_IDENTIFIER);
				
				[tMutableSectionArray release];
			}
		}
		
		CFPreferencesAppSynchronize((CFStringRef) APPLE_DOCK_BUNDLE_IDENTIFIER);
		
		return YES;
	}
	
	return NO;
}

+ (BOOL) removeTileWithItemAtPath:(NSString *) inPath options:(NSUInteger) inOptions
{
	if ((inOptions & kRemoveDuplicates)==kRemoveDuplicates)
	{
		// Error (not supported)
		
		usage_remove();
	}
	else
	{
		if (inPath!=nil)
		{
			if ((inOptions & kBundleIdentifier)==kBundleIdentifier)
			{
				return [EMUtility removeTiteWithItemAtPath:inPath comparing:kBundleIdentifierComparison options:inOptions];
			}
			else
			{
				// Check whether it's an absolute path or not
				
				if ([inPath characterAtIndex:0]=='/')
				{
					return [EMUtility removeTiteWithItemAtPath:inPath comparing:kPathComparison options:inOptions];
				}
				else
				{
					return [EMUtility removeTiteWithItemAtPath:inPath comparing:kNameComparison options:inOptions];
				}
			}
		}
	}
	
	return NO;
}

@end
