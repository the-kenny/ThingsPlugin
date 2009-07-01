#import <Foundation/Foundation.h>

@protocol PluginDelegate <NSObject>

// This data dictionary will be converted into JSON by the extension.  This method will get called
// any time an application is closed or the badge changes on the bundles in the LIManagedBundles 
// setting and when the phone is woken up.  It's the responsibility of the plugin to only load the data
// if it needs to.
- (NSDictionary*) data;

@optional
// Called before the first call to 'data' and any time the settings are updated in the Settings app.
- (void) setPreferences:(NSDictionary*) prefs;

@end

@interface ThingsPlugin : NSObject <PluginDelegate> {

}
- (NSDictionary*) data;
@end

@implementation ThingsPlugin

- (NSDictionary*) data {
	
  NSArray *todos = [NSArray arrayWithObjects:
							  [NSDictionary dictionaryWithObjectsAndKeys:
											  @"Irgendwas kaufen", @"text", 
											@"01.01.1970", @"due", 
											nil], 
							nil];

  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:todos, @"today", nil];

	return dict;
}


@end

int main() {
  //printf("42");
}
