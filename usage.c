/*
 Copyright (c) 2012, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include "usage.h"
#include <stdio.h>
#include <stdlib.h>

void usage_add(void)
{
	(void)fprintf(stderr, "%s\n","emmett add: add item to the Dock\n"
				  "Usage: emmet add <path>\n"
				  "Common options:\n"
				  "   -no-kill             Do not kill and relaunch the Dock\n"
				  "   -no-duplicate        Remove existing application items with the same bundle-identifier");
}

void usage_add_missing_object(void)
{
	(void)fprintf(stderr, "%s\n","emmett: add: missing <path>\n"
				  "Usage: emmet add [options] <path>\n"
				  "       emmet add -help");
}

void usage_remove(void)
{
	(void)fprintf(stderr, "%s\n","emmett remove: remove item(s) from the Dock\n"
				  "Usage: emmet remove <path|name>\n"
				  "Common options:\n"
				  "   -no-kill             Do not kill and relaunch the Dock\n"
				  "   -bundle-identifier   Look for items with a bundle-identifier identical to name\n"
				  "   -regex               Evaluate path|name as a regular expression\n");
}

void usage_remove_missing_object(void)
{
	(void)fprintf(stderr, "%s\n","emmett: remove: missing <path>\n"
				  "Usage: emmet remove [options] <path|name>\n"
				  "       emmet remove -help");
}

void usage_help(void)
{
	(void)fprintf(stderr, "%s\n","help\t\tdisplay more detailed help");
}

void usage_verb(const char * inError)
{
	(void)fprintf(stderr, "emmet: %s\n%s",inError,
				                 "Usage: emmett <verb> <options>\n"
								 "<verb> is one of the following:\n"
								 "help\nadd\nremove\n");
}

void usage(void)
{
	(void)fprintf(stderr, "%s\n","Usage: emmett <verb> <options>\n"
				  "<verb> is one of the following:\n"
				  "help\nadd\nremove\n\n"
				  "Usage: emmet add [options] <path>\n"
				  "       emmet add -help\n\n"
				  "Usage: emmet remove [options] <path|name>\n"
				  "       emmet remove -help\n");
}

