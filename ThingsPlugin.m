#import <Foundation/Foundation.h>
#import <sqlite3.h>

//NSString *databasePath = @"/User/Applications/AC624048-1944-4019-8581-407A502E19AC/Documents/db.sqlite3";

NSString* preferencesPath = @"/User/Library/Preferences/cx.ath.the-kenny.ThingsPlugin.plist";

NSString *todaySql = @"select title,dueDate from Task where status = 1 and type = 2 and flagged = 1";

NSString *nextSql = @"select title,dueDate from Task where status = 1 and type = 2 and focus = 2";

NSString *somedaySql = @"select title,dueDate from Task where status = 1 and type = 2 and focus = 16";

NSString *inboxSql = @"select title,dueDate from Task where status = 1 and type = 2 and focus = 1";

@protocol PluginDelegate <NSObject>

// This data dictionary will be converted into JSON by the extension.  This method will get called
// any time an application is closed or the badge changes on the bundles in the LIManagedBundles setting and when the phone is woken up.  It'
- (NSDictionary*) data;

@optional
// Called before the first call to 'data' and any time the settings are updated in the Settings app.
- (void) setPreferences:(NSDictionary*) prefs;

@end


@interface ThingsPlugin : NSObject <PluginDelegate> {
  NSDate *lastCheckout;
  NSDictionary *lastData;
  NSMutableDictionary *preferences;
  int queryLimit;
  //bool preferencesChanged;
  bool enabled;
}

- (NSDictionary*) data;
@end

@implementation ThingsPlugin

- (id)init {
  self = [super init];

  lastData = nil;
  lastCheckout = nil;

  preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:preferencesPath];

  queryLimit = [[preferences valueForKey:@"Limit"] intValue];
  enabled = [[preferences valueForKey:@"Enabled"] boolValue];
  
  NSString* databasePath = [preferences objectForKey:@"databasePath"];
  if(databasePath == nil || [databasePath length] == 0) {
	NSLog(@"We do not have the database path, going to search for it.");
	NSFileManager* fm = [NSFileManager defaultManager];

	NSString* appPath = @"/User/Applications/";
	NSArray* uuidDirs = [fm directoryContentsAtPath:appPath];
	NSEnumerator *e = [uuidDirs objectEnumerator];
	bool cont = true;
	NSString* uuid = nil;
	while(cont && (uuid = [e nextObject])) {
	  if([[fm directoryContentsAtPath:[appPath stringByAppendingString:uuid]] containsObject:@"Things.app"]) {
		[preferences setObject:[NSString stringWithFormat:@"/User/Applications/%@/Documents/db.sqlite3", uuid] forKey:@"databasePath"];
		[preferences writeToFile:preferencesPath atomically:YES];
		cont = false;
		NSLog(@"Found the path: %@", [preferences objectForKey:@"databasePath"]);
	  }
	}
	
  }

  NSLog(@"Initialized!");

  return self;
}

- (void)dealloc {
  if(lastData != nil)
	[lastData release];
  
  if(lastCheckout != nil)
	[lastCheckout release];

  [preferences release];

  [super dealloc];
}

- (NSDictionary*) readFromDatabase {
  //NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];


  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:1];
  NSMutableArray *todos = [NSMutableArray arrayWithCapacity:4];

  sqlite3 *database = NULL;

  //if(sqlite3_open([[defaults stringForKey:@"databasePath"] UTF8String], &database) == SQLITE_OK) {
  if(sqlite3_open([[preferences objectForKey:@"databasePath"] UTF8String], &database) == SQLITE_OK) {

	/*
	NSString *sql = [NSString stringWithFormat:@"%@ limit %i;",
							  todaySql,
							  [[preferences valueForKey:@"Limit"] intValue]];
	*/

	NSString *sql = [NSString stringWithFormat:@"%@ limit %i", todaySql, queryLimit];

	// Setup the SQL Statement and compile it for faster access
	sqlite3_stmt *compiledStatement;
	if(sqlite3_prepare_v2(database, [sql UTF8String], -1, &compiledStatement, NULL) == SQLITE_OK) {
	  NSLog(@"Database checkout worked!");


	  // Loop through the results and add them to the feeds array
	  while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
		const char *cText = sqlite3_column_text(compiledStatement, 0);
		if(cText == NULL)
		  cText = "";

		const char *cDue  = sqlite3_column_text(compiledStatement, 1);
		if(cDue == NULL)
		  cDue = "";
		
		NSString *aText = [NSString stringWithUTF8String:cText];
		NSString *aDue = [NSString stringWithUTF8String:cDue];

		NSDictionary *todoDict = [NSDictionary dictionaryWithObjectsAndKeys:
												 aText, @"text",
											   aDue, @"due",
											   nil];
		
		[todos addObject:todoDict];
	  }
	  
	}
	// Release the compiled statement from memory
	sqlite3_finalize(compiledStatement);
  }

  sqlite3_close(database);

  [dict setObject:todos forKey:@"todos"];  
  [dict setObject:preferences forKey:@"preferences"];
  //[dict retain];
  
  //[pool drain];

  NSLog(@"Successfully read from database.");


  return dict;
}

- (NSDictionary*) data {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  if(enabled == true) {

	NSDictionary *fileAttributes = [[NSFileManager defaultManager] 
									 fileAttributesAtPath:[preferences objectForKey:@"databasePath"]
									 traverseLink:YES];

	NSDate* lastModified = [fileAttributes objectForKey:NSFileModificationDate];

	if(lastCheckout == nil || lastData == nil ||
	   [lastModified compare:lastCheckout] == NSOrderedDescending) {
	  NSLog(@"We don't have the last time or data, updating");

	  NSDictionary* dict = [self readFromDatabase];
	
	  if(lastData != nil)
		[lastData release];
	  lastData = [dict retain];

	  if(lastCheckout != nil)
		[lastCheckout release];
	  lastCheckout = [lastModified retain];

	  NSLog(@"Succesfully got new data");
	} else {
	  NSLog(@"No update");
	}
  
	[pool drain];
  
	return lastData;
  } else {
	[pool drain];
	NSLog(@"ThingsPlugin is disabled.");
	return [NSDictionary dictionaryWithObjectsAndKeys:
						   // preferences, @"preferences", 
						   [NSArray array], @"todos",
						 nil];
  }
  
}

- (void) setPreferences:(NSDictionary*) prefs {
  [preferences release];
  preferences = [prefs retain];

  queryLimit = [[preferences valueForKey:@"Limit"] intValue];
  enabled = [[preferences valueForKey:@"Enabled"] boolValue];


  //Force an update of the data
  if(lastData != nil) {
	[lastData release];
	lastData = nil;
  }

  NSLog(@"PreferencesChanged");
}

@end

int main() {
  /*
  //  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  ThingsPlugin* p = [[ThingsPlugin alloc] init];
  NSLog(@"%@", [p data]);

  //  [pool release];
  */
}
