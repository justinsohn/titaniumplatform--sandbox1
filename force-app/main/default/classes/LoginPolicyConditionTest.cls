@isTest(Seealldata=true)
public class LoginPolicyConditionTest {
    @isTest public static void testLoginPolicy()
    {
        System.Test.startTest();
        string x = 'Account';
        LoginHistory l = [ SELECT Platform FROM LoginHistory Limit 1];
        /* Create a map for the event we’re going to build. */
        Map<String, String> eventData = new Map<String, String>();
        eventData.put('LoginHistoryId', l.Id);
            
        TxnSecurity.Event test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Account', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            eventData); /* data - Map with info about this event. */
        
        //datas.put('NumberOfRecords', '60');
        //datas.put('EntityName', 'Account');
        //test_class.Event(x, x, x, x, x, x, datentime, data);
        
        LoginPolicyCondition target = new LoginPolicyCondition();
        target.evaluate(test_class);
        System.Test.stopTest();
        
        
    }
}