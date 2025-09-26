@isTest(Seealldata=true)
public class EnhancedLoginEventConditionTest {
    @isTest public static void testLoginEventCondition()
    {
        System.Test.startTest();
        string x = 'Account';
        LoginHistory l = [ SELECT Platform FROM LoginHistory Limit 1];
        /* Create a map for the event we’re going to build. */
        Map<String, String> eventData = new Map<String, String>();
        eventData.put('LoginHistoryId', l.Id);
        
        LoginEvent test_class = new LoginEvent();
        test_class.EventDate = Datetime.newInstance(2016, 2, 15);
        test_class.UserId = UserInfo.getUserId();
        
        //datas.put('NumberOfRecords', '60');
        //datas.put('EntityName', 'Account');
        //test_class.Event(x, x, x, x, x, x, datentime, data);
        
        EnhancedLoginEventCondition target = new EnhancedLoginEventCondition();
        target.evaluate(test_class);
        System.Test.stopTest();
    }
}