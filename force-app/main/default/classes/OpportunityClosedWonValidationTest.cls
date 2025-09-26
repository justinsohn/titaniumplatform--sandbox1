@isTest
private class OpportunityClosedWonValidationTest {

    @isTest
    static void testOpportunityClosedWonWithMissingDates() {
        // Create an Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create an Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        // Create a Product2
        Product2 prod = new Product2(Name = 'Test Product', isActive = true);
        insert prod;

        // Create a PricebookEntry (required for OLI)
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // Create Opportunity Product with missing Revenue Dates
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            TotalPrice = 100
        );
        insert oli;

        // Try to update Opportunity to Closed Won → should fail
        opp.StageName = 'Closed Won';

        Test.startTest();
        try {
            update opp;
            System.assert(false, 'Expected an error but none was thrown');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('All Opportunity Products must have Revenue Start and Revenue End Dates'));
        }
        Test.stopTest();
    }

    @isTest
    static void testOpportunityClosedWonWithValidDates() {
        // Create an Account
        Account acc = new Account(Name = 'Test Account 2');
        insert acc;

        // Create an Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp Valid',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        // Create a Product2
        Product2 prod = new Product2(Name = 'Test Product 2', isActive = true);
        insert prod;

        // Create a PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            UnitPrice = 200,
            IsActive = true
        );
        insert pbe;

        // Create Opportunity Product WITH Revenue Dates
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            TotalPrice = 200,
            Revenue_Start_Date__c = Date.today(),
            Revenue_End_Date__c = Date.today().addMonths(1)
        );
        insert oli;

        // Try to update Opportunity to Closed Won → should succeed
        opp.StageName = 'Closed Won';

        Test.startTest();
        update opp;  // no exception expected
        Test.stopTest();
    }
}