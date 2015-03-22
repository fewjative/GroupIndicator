#import <UIKit/UIKit.h>
#import <substrate.h>

static bool enableTweak = NO;
static bool memberCount = NO;
static bool hideWhenNamed = NO;
static NSString * indicatorText = nil;

@interface BBBulletin
@property(retain, nonatomic) NSDictionary * context;
@end

@interface SBBulletinBannerItem
-(BBBulletin*)seedBulletin;
@end

@interface SBAwayBulletinListItem
-(BBBulletin*)activeBulletin;
@end

%hook SBBulletinBannerItem

//Does not have a subtitle(unlike what is displayed on the lockscreen)

-(NSString*)title
{
	NSString * title = %orig;

	if(!enableTweak)
		return title;

	NSDictionary * assistantContext = [NSDictionary dictionaryWithDictionary:[self seedBulletin].context[@"AssistantContext"]];

	if([[assistantContext allKeys] containsObject:@"msgRecipients"])
	{
		if(memberCount)
		{
			int count = [assistantContext[@"msgRecipients"] count] - 1;
			title = [NSString stringWithFormat:@"+%d %@",count,title];
		}
		else
			title = [NSString stringWithFormat:@"%@%@",indicatorText,title];

		return title;
	}
	else
		return title;
}

%end

%hook SBAwayBulletinListItem

//the bulletin subtitle contains the group name, could use that to list all of the members in the group.

-(NSString*)title
{
	NSString * title = %orig;

	if(!enableTweak)
		return title;

	NSDictionary * assistantContext = [NSDictionary dictionaryWithDictionary:[self activeBulletin].context[@"AssistantContext"]];

	if([[assistantContext allKeys] containsObject:@"msgRecipients"])
	{
		if(hideWhenNamed)
		{
			if([self subtitle] && [[self subtitle] length] > 0)
				return title;
		}

		if(memberCount)
		{
			int count = [assistantContext[@"msgRecipients"] count] - 1;
			title = [NSString stringWithFormat:@"+%d %@",count,title];
		}
		else
			title = [NSString stringWithFormat:@"%@%@",indicatorText,title];

		return title;
	}
	else
		return title;
}

%end

@interface SBAlertItem : NSObject
-(id)_groupID;
-(id)name;
-(id)address;
-(BBBulletin*)bulletin;
-(UIAlertView*)alertSheet;
@end

%hook SBAlertItemsController

-(void)activateAlertItem:(id)alert
{
	%orig;

	if(!enableTweak)
		return;

	if([(SBAlertItem*)alert isKindOfClass:%c(CKMessageAlertItem)])
	{
		NSDictionary * assistantContext = [NSDictionary dictionaryWithDictionary:[alert bulletin].context[@"AssistantContext"]];

		if([[assistantContext allKeys] containsObject:@"msgRecipients"])
		{
			NSString * title;

			if(memberCount)
			{
				int count = [assistantContext[@"msgRecipients"] count] - 1;
				title = [NSString stringWithFormat:@"+%d %@",count,[[alert alertSheet] title]];
			}
			else
				title = [NSString stringWithFormat:@"%@%@",indicatorText,[[alert alertSheet] title]];

			[alert alertSheet].title = title;
		}
		else
			return;
	}
}

%end

static void loadPrefs() 
{
    CFPreferencesAppSynchronize(CFSTR("com.joshdoctors.groupindicator"));
    enableTweak = !CFPreferencesCopyAppValue(CFSTR("enableTweak"), CFSTR("com.joshdoctors.groupindicator")) ? NO : [(id)CFPreferencesCopyAppValue(CFSTR("enableTweak"), CFSTR("com.joshdoctors.groupindicator")) boolValue];
	memberCount = !CFPreferencesCopyAppValue(CFSTR("memberCount"), CFSTR("com.joshdoctors.groupindicator")) ? NO : [(id)CFPreferencesCopyAppValue(CFSTR("memberCount"), CFSTR("com.joshdoctors.groupindicator")) boolValue];
    hideWhenNamed = !CFPreferencesCopyAppValue(CFSTR("hideWhenNamed"), CFSTR("com.joshdoctors.groupindicator")) ? NO : [(id)CFPreferencesCopyAppValue(CFSTR("hideWhenNamed"), CFSTR("com.joshdoctors.groupindicator")) boolValue];
    indicatorText = (NSString*)CFPreferencesCopyAppValue(CFSTR("indicatorText"), CFSTR("com.joshdoctors.groupindicator")) ?: @"+";
    [indicatorText retain];
}

%ctor 
{
	NSLog(@"[GroupIndicator]Loading....");
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                NULL,
                                (CFNotificationCallback)loadPrefs,
                                CFSTR("com.joshdoctors.groupindicator/settingschanged"),
                                NULL,
                                CFNotificationSuspensionBehaviorDeliverImmediately);
    loadPrefs();
}