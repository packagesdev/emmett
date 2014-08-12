/*
 Copyright (c) 2012-2014, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Foundation/Foundation.h>

#include <getopt.h>

#include "usage.h"

#import "EMUtility.h"

#define NO_KILL_OPT				"no-kill"
#define NO_DUPLICATE_OPT		"no-duplicate"
#define BUNDLE_IDENTIFIER_OPT	"bundle-identifier"
#define REGEX_OPT				"regex"
#define HELP_OPT				"help"

#define __EMMET_VERSION__				"1.0"

int main (int argc, const char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    static const struct option long_options[]=
	{
		{NO_KILL_OPT, no_argument,NULL,0},
		{NO_DUPLICATE_OPT, no_argument,NULL,0},
		{BUNDLE_IDENTIFIER_OPT, no_argument,NULL,0},
		{REGEX_OPT, no_argument,NULL,0},
		{HELP_OPT, no_argument,NULL,0},
		{NULL, 0, NULL, 0} /* End of array need by getopt_long do not delete it*/
	};
	
	int helpOptions=0;
	int noKillOptions=0;
	int tOptions=0;
	BOOL tSuccess=NO;
	
	// Can not be run fron the root account
	
	if (getuid()==0 || geteuid()==0)
	{
		(void)fprintf(stderr, "%s\n","emmett: super-user not permitted for your own good");
		
		return 1;
	}
	
	while (1)
	{
		int c;
		int option_index = 0;
		
		c = getopt_long_only(argc, (char * const *)argv, "",long_options, &option_index);
		
		if (c== EOF)
		{
			break;
		}
		else if (c==0)
		{
			const char * tOptionName;
			
			tOptionName=long_options[option_index].name;
			
			if (strncmp(NO_KILL_OPT,tOptionName,strlen(NO_KILL_OPT))==0)
			{
				noKillOptions=1;
			}
			else if (strncmp(NO_DUPLICATE_OPT,tOptionName,strlen(NO_DUPLICATE_OPT))==0)
			{
				tOptions|=kRemoveDuplicates;
			}
			else if (strncmp(BUNDLE_IDENTIFIER_OPT,tOptionName,strlen(BUNDLE_IDENTIFIER_OPT))==0)
			{
				tOptions|=kBundleIdentifier;
			}
			else if (strncmp(REGEX_OPT,tOptionName,strlen(REGEX_OPT))==0)
			{
				tOptions|=kRegularExpression;
			}
			else if (strncmp(HELP_OPT,tOptionName,strlen(HELP_OPT))==0)
			{
				helpOptions=1;
			}
		}
	}
	
	if (optind < argc)
    {
		const char * tVerb;
		
		tVerb=argv[optind];
		
		if (strncmp("add",tVerb,3)==0)
		{
			optind++;
			
			if (optind < argc)
			{
				NSString * tPath;
				const char * tCPath;
				size_t tLength;
				
				tCPath=argv[optind];
				
				tLength=strlen(tCPath);
				
				tPath=[[NSFileManager defaultManager] stringWithFileSystemRepresentation:tCPath length:tLength];
				
				if (noKillOptions==0)
				{
					if ([EMUtility quitAndStopDockProcess]==NO)
					{
						return 1;
					}
				}
				
				tSuccess=[EMUtility addTileWithItemAtPath:tPath options:tOptions];
				
				if (noKillOptions==0)
				{
					if ([EMUtility resumeAndKillDockProcess]==NO)
					{
						return 1;
					}
				}
			}
			else
			{
				if (helpOptions==1)
				{
					usage_add();
					
					tSuccess=YES;
				}
				else
				{
					usage_add_missing_object();
				}
			}
		}
		else if (strncmp("remove",tVerb,6)==0)
		{
			optind++;
			
			if (optind < argc)
			{
				
				NSString * tPath;
				const char * tCPath;
				size_t tLength;
				
				tCPath=argv[optind];
				
				tLength=strlen(tCPath);
				
				tPath=[[NSFileManager defaultManager] stringWithFileSystemRepresentation:tCPath length:tLength];
				
				if (noKillOptions==0)
				{
					if ([EMUtility quitAndStopDockProcess]==NO)
					{
						return 1;
					}
				}
				
				tSuccess=[EMUtility removeTileWithItemAtPath:tPath options:tOptions];
				
				if (noKillOptions==0)
				{
					if ([EMUtility resumeAndKillDockProcess]==NO)
					{
						return 1;
					}
				}
			}
			else
			{
				if (helpOptions==1)
				{
					usage_remove();
					
					tSuccess=YES;
				}
				else
				{
					usage_remove_missing_object();
				}
			}
		}
		else if (strncmp("help",tVerb,4)==0)
		{
			if (helpOptions==1)
			{
				usage_help();
			}
			else
			{
				usage();
			}

			tSuccess=YES;
		}
		else 
		{
			usage_verb("verb not recognized");
		}
	}
	else
	{
		usage_verb("missing verb");
	}
	
    [pool drain];
    
	return ((tSuccess==YES) ? 0 : 1);
}
