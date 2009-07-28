#import <Foundation/Foundation.h>
#import <sqlite3.h>

//NSString *databasePath = @"/User/Applications/AC624048-1944-4019-8581-407A502E19AC/Documents/db.sqlite3";

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

  NSDictionary* sqlDict;
  NSString* preferencesPath;

  NSAutoreleasePool* pool;
}

- (NSDictionary*) data;
@end

@implementation ThingsPlugin

//Init initializes some variables and performs initial things like searching
//the database
- (id)init {
  self = [super init];

  lastData = nil;
  lastCheckout = nil;

  pool = [[NSAutoreleasePool alloc] init];

  preferencesPath = @"/User/Library/Preferences/cx.ath.the-kenny.ThingsPlugin.plist";

  //The different sql-queries
  NSString *todaySql = @"select title,dueDate from Task where status = 1 and type = 2 and flagged = 1";

  NSString *nextSql = @"select title,dueDate from Task where status = 1 and type = 2 and focus = 2";

  NSString *somedaySql = @"select title,dueDate from Task where status = 1 and type = 2 and focus = 16";

  NSString *inboxSql = @"select title,dueDate from Task where status = 1 and type = 2 and focus = 1";

  NSString *allSql = @"select title,dueDate from Task where status = 1";

  NSString *todaySqlProjects = @"select t1.title,t1.dueDate,t2.title from Task as t1  left join Task as t2 on t2.uuid = t1.project where t1.status = 1 and t1.type = 2 and t1.flagged = 1";

  NSString *nextSqlProjects = @"select t1.title,t1.dueDate,t2.title from Task as t1  left join Task as t2 on t2.uuid = t1.project where status = 1 and type = 2 and focus = 2";

  NSString *somedaySqlProjects = @"select t1.title,t1.dueDate,t2.title from Task as t1  left join Task as t2 on t2.uuid = t1.project where status = 1 and type = 2 and focus = 16";

  NSString *inboxSqlProjects = @"select t1.title,t1.dueDate,t2.title from Task as t1  left join Task as t2 on t2.uuid = t1.project where status = 1 and type = 2 and focus = 1";

  NSString *allSqlProjects = @"select t1.title,t1.dueDate,t2.title from Task as t1  left join Task as t2 on t2.uuid = t1.project where status = 1";

  //Add the to a dictionary to have access witht the settings-keys
  sqlDict = [[NSDictionary alloc] initWithObjectsAndKeys:
									todaySql, @"today",
								  nextSql, @"next",
								  somedaySql, @"someday",
								  inboxSql, @"inbox",
								  allSql, @"all",
								  todaySqlProjects, @"todayProjects",
								  nextSqlProjects, @"nextProjects",
								  somedaySqlProjects, @"somedayProjects",
								  inboxSqlProjects, @"inboxProjects",
								  allSqlProjects, @"allProjects",
								  nil];

  preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:preferencesPath];

  queryLimit = [[preferences valueForKey:@"Limit"] intValue];

  NSFileManager* fm = [NSFileManager defaultManager];
  
  NSString* databasePath = [preferences objectForKey:@"databasePath"];

  //If databasePath isn't set, search for the dir and set it
  if(databasePath == nil || [fm fileExistsAtPath:[preferences objectForKey:@"databasePath"]] == NO) {
	NSLog(@"We do not have the database path, going to search for it.");

	//Search for the application-directory (Recursively traverse the App-Dir)
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

  NSLog(@"[ThingsPlugin] Initialized!");

  return self;
}

- (void)dealloc {
  if(lastData != nil)
	[lastData release];
  
  if(lastCheckout != nil)
	[lastCheckout release];

  [sqlDict release];

  [preferences release];

  [pool release];

  [super dealloc];
}

//readFromDatabase reads the data from the database and returns a dictionary 
//which can be passed to plugin.js without changing it.
- (NSDictionary*) readFromDatabase {
  //NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];


  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:1];
  NSMutableArray *todos = [NSMutableArray arrayWithCapacity:4];

  sqlite3 *database = NULL;

  if(sqlite3_open([[preferences objectForKey:@"databasePath"] UTF8String], &database) == SQLITE_OK) {

	/*
	  NSString *sql = [NSString stringWithFormat:@"%@ limit %i;",
	  todaySql,
	  [[preferences valueForKey:@"Limit"] intValue]];
	*/

	//Build the query (query + ordering + limit)
	NSString *sql = [NSString stringWithFormat:@"%@ order by createdDate %@ limit %i", 
							  [sqlDict objectForKey:
										 [preferences objectForKey:@"List"]], 
							  [preferences objectForKey:@"Order"],
							  queryLimit];

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

//data returns the dictionary for plugin.js, the data is cached and it only
//updates the data if the file was changed since the last checkout
- (NSDictionary*) data {
  NSAutoreleasePool *datapool = [[NSAutoreleasePool alloc] init];

  //Check if the file was modified since the last change
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
  
  [datapool drain];
  
  return lastData;
}

- (void) setPreferences:(NSDictionary*) prefs {
  [preferences release];
  preferences = [prefs retain];

  queryLimit = [[preferences valueForKey:@"Limit"] intValue];

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
