@isTest(Seealldata=true)
public class AccountExportPolicyConditionTest {
     @isTest public static void testAccountExport()
    {
        System.Test.startTest();
        string x = 'Account';
        Map<string,string> datas = new Map<string, string>{'NumberOfRecords' => '60', 'EntityName' => 'Account'};
            
        TxnSecurity.Event test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Account', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
        //datas.put('NumberOfRecords', '60');
        //datas.put('EntityName', 'Account');
        //test_class.Event(x, x, x, x, x, x, datentime, data);
        
        SF2080_SV3_Account_Export_300_799 target = new SF2080_SV3_Account_Export_300_799();
        target.evaluate(test_class);
        
        SF2070_SV2_Account_Export_800_1699 target2 = new SF2070_SV2_Account_Export_800_1699();
        target2.evaluate(test_class);
        
        SF2060_SV1_Account_Export_1700 target3 = new SF2060_SV1_Account_Export_1700();
        target3.evaluate(test_class);
        
        datas = new Map<string, string>{'NumberOfRecords' => '900', 'EntityName' => 'Account'};
        
        test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Account', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
        target.evaluate(test_class);        
        target2.evaluate(test_class);
        target3.evaluate(test_class);
        
        datas = new Map<string, string>{'NumberOfRecords' => '1700', 'EntityName' => 'Account'};
        
        test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Account', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
        target.evaluate(test_class);        
        target2.evaluate(test_class);
        target3.evaluate(test_class);
        
        System.Test.stopTest();
        
    }
}