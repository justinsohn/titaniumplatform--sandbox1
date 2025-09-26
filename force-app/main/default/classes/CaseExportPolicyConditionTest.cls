@isTest(Seealldata=true)
public class CaseExportPolicyConditionTest {
     @isTest public static void test_condition()
    {
        System.Test.startTest();
        string x = 'Account';
        Map<string,string> datas = new Map<string, string>{'NumberOfRecords' => '60', 'EntityName' => 'Case'};
            
        TxnSecurity.Event test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Case', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
        //datas.put('NumberOfRecords', '60');
        //datas.put('EntityName', 'Account');
        //test_class.Event(x, x, x, x, x, x, datentime, data);
        
        SF2090_SV1_Cases_Export_16000 target = new SF2090_SV1_Cases_Export_16000();
        target.evaluate(test_class);
        
        SF2100_SV2_Cases_Export_10000_15999 target2 = new SF2100_SV2_Cases_Export_10000_15999();
        target2.evaluate(test_class);
        
        SF2110_SV3_Cases_Export_500_9999 target3 = new SF2110_SV3_Cases_Export_500_9999();
        target3.evaluate(test_class);
        
        
        datas = new Map<string, string>{'NumberOfRecords' => '11000', 'EntityName' => 'Case'};
            
        test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Case', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            datas); /* data - Map with info about this event. */
       
        target.evaluate(test_class);
        target2.evaluate(test_class);
        target3.evaluate(test_class);
        
         datas = new Map<string, string>{'NumberOfRecords' => '16000', 'EntityName' => 'Case'};
            
        test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Case', /* entityName */
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