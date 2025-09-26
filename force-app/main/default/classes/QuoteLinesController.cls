public class QuoteLinesController { 
    public class QuoteLineTable {
        //public String endCustomer {get;set;}
        //public String projectName {get;set;}
        public sbaa__Approval__c approval {get;set;}
        public  QuoteAndLineDetail quoteDetail {get;set;}
        //public  QuoteLineSummary quoteLineLabSummary {get;set;}
        //public  QuoteLineSummary quoteLineProdSummary {get;set;}
        
        public  List<ApprovalDetails> approvalDetailsList {get;set;}
    }
    
    public class ApprovalDetails {
        public sbaa__Approval__c approval {get;set;}
        public  List<QuoteLineSummary> quoteLineSummaryList {get;set;}
    }
    
    public class QuoteLineSummary {
        public boolean show {get;set;}
        public String site {get;set;}
        public QuoteAndLineDetail summary {get;set;}
        public List<QuoteAndLineDetail> quoteLineList {get;set;}
    }
    
    public class QuoteAndLineDetail {
        public String productCode {get;set;}
        public String approvalTier {get;set;}
        public Decimal listPrice {get;set;}
        public Decimal discountAmount {get;set;}
        public Decimal effectiveDiscount {get;set;}
        public Decimal netPrice {get;set;}
    }
    
    public String approvalId {get; set;} 
    public Map<String, List<SBQQ__QuoteLine__c>> approverToQuoteLineListMap {get;set;}
    public Map <String, String> operatorMap = new Map<String, String> {
                'equals' => 'y = x',
                'not equals' => 'y != x',
                'less than' => 'y < x',
                'less or equals' => 'y <= x',
                'greater than' => 'y > x',
                'greater or equals' => 'y >= x',
                'starts with' => 'y LIKE \'x%\'',
                'ends with' => 'y LIKE \'%x\'',
                'contains' => 'y LIKE \'%x%\'',
                'does not contain' => 'NOT y LIKE \'%x%\''
    };
    
    public sbaa__Approval__c approval {
        get {
            return [SELECT sbaa__AssignedTo__r.Name, sbaa__Rule__r.Name, Quote__r.SBQQ__Account__r.Name, Quote__r.SBQQ__Opportunity2__r.Customer_Project_Name__c FROM sbaa__Approval__c WHERE Id = :approvalId];
        }   
    }
    
     public QuoteLineTable quoteLineTableDetails {
        get {
            QuoteLineTable quoteLineTable1 = new QuoteLineTable();
            List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
            List<QuoteAndLineDetail> quoteLineLabList = new List<QuoteAndLineDetail>();
            List<QuoteAndLineDetail> quoteLineProdList = new List<QuoteAndLineDetail>();
            //Set<Id> approvalVariableIdSet = new Set<Id>();
            //Map<String, String> approvalVariableToQueryMap = new Map<String, String>();
            Map<String, List<SBQQ__QuoteLine__c>> productCategoryToQuoteListMap = new Map<String, List<SBQQ__QuoteLine__c>>();
            Map<String, sbaa__Approval__c> productCategoryToApprovalMap = new Map<String, sbaa__Approval__c>();
            Set<String> productCategorySet = new Set<String>();
            
            sbaa__Approval__c approval = [SELECT Id, sbaa__Rule__c, sbaa__Rule__r.Name, sbaa__Rule__r.sbaa__ConditionsMet__c,  sbaa__Rule__r.sbaa__AdvancedCondition__c, sbaa__Approver__r.Name, Quote__c, Quote__r.SBQQ__Opportunity2__r.Customer_Project_Name__c, Quote__r.SBQQ__Account__r.Name, sbaa__ApprovalStep__c, Quote__r.Discount_Reason__c, sbaa__Approver__c FROM sbaa__Approval__c WHERE Id = :approvalId];
            
            for(sbaa__Approval__c appr : [SELECT Id, sbaa__Rule__r.Name FROM sbaa__Approval__c WHERE sbaa__ApprovalStep__c = :approval.sbaa__ApprovalStep__c AND sbaa__Approver__c = :approval.sbaa__Approver__c AND Quote__c = : approval.Quote__c]) {
                if(appr.sbaa__Rule__r.Name.contains(' Level')) {
                    productCategoryToApprovalMap.put(appr.sbaa__Rule__r.Name.substringBefore(' Level'), appr);
                    productCategorySet.add(appr.sbaa__Rule__r.Name.substringBefore(' Level'));
                }
            }
            
            system.debug('<DEBUG>  productCategorySet ' + productCategorySet);
            
            quoteLineList = [SELECT CPQ_Price_Ceiling__c, CPQ_Price_Floor__c, CPQ_Price_Floor_or_Ceiling_Met__c, CPQ_Product_Code_Formatted__c, Discount_Text__c, SBQQ__NetPrice__c, SBQQ__ProductCode__c, SBQQ__Quote__r.Name, Lab__c, SBQQ__ListPrice__c, SBQQ__TotalDiscountAmount__c, SBQQ__TotalDiscountRate__c, Group_Label__c, Product_Category__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :approval.Quote__c AND Product_Category__c IN :productCategorySet ORDER BY SBQQ__TotalDiscountRate__c DESC, Product_Category__c ASC];
            
            SBQQ__Quote__c quote = [SELECT Id, SBQQ__Account__r.Name, SBQQ__Opportunity2__r.Customer_Project_Name__c, SBQQ__ListAmount__c, SBQQ__CustomerDiscount__c, SBQQ__AverageCustomerDiscount__c, SBQQ__NetAmount__c, SBQQ__AdditionalDiscountAmount__c FROM SBQQ__Quote__c WHERE Id = :approval.Quote__c];
            
            //quoteLineTable1.endCustomer = quote.SBQQ__Account__r.Name;
            //quoteLineTable1.projectName = quote.SBQQ__Opportunity2__r.Customer_Project_Name__c;
            quoteLineTable1.approval = approval;
            quoteLineTable1.quoteDetail = new QuoteAndLineDetail();
            quoteLineTable1.approvalDetailsList = new List<ApprovalDetails>();
            quoteLineTable1.quoteDetail.listPrice = quote.SBQQ__ListAmount__c;
            quoteLineTable1.quoteDetail.discountAmount = quote.SBQQ__AdditionalDiscountAmount__c != null ? quote.SBQQ__AdditionalDiscountAmount__c : 0;
            quoteLineTable1.quoteDetail.effectiveDiscount = quote.SBQQ__AverageCustomerDiscount__c != null ? quote.SBQQ__AverageCustomerDiscount__c : 0;
            quoteLineTable1.quoteDetail.netPrice = quote.SBQQ__NetAmount__c;
            
            for(SBQQ__QuoteLine__c qli : quoteLineList) {
                if(productCategoryToQuoteListMap.containsKey(qli.Product_Category__c))
                    productCategoryToQuoteListMap.get(qli.Product_Category__c).add(qli);
                else
                    productCategoryToQuoteListMap.put(qli.Product_Category__c, new List<SBQQ__QuoteLine__c>{qli});
            }
            
            system.debug('<DEBUG> Product Category ' + productCategoryToQuoteListMap.keySet());
            for(String key : productCategoryToQuoteListMap.keySet()) {
                ApprovalDetails approvalDetails = new ApprovalDetails();
                approvalDetails.approval = productCategoryToApprovalMap.get(key);
                approvalDetails.quoteLineSummaryList = new List<QuoteLineSummary>();
                Map<String, QuoteLineSummary> groupToQuoteLineSummaryMap = new Map<String, QuoteLineSummary>();
                
                for(SBQQ__QuoteLine__c qli : productCategoryToQuoteListMap.get(key)) {
                    QuoteAndLineDetail qliWrapper = new QuoteAndLineDetail();
                    QuoteLineSummary qls = new QuoteLineSummary();
                    
                    qliWrapper.productCode = qli.SBQQ__ProductCode__c;
                    qliWrapper.listPrice = qli.SBQQ__ListPrice__c != null ? qli.SBQQ__ListPrice__c : 0;
                    qliWrapper.discountAmount = qli.SBQQ__TotalDiscountAmount__c != null ? qli.SBQQ__TotalDiscountAmount__c : 0;
                    qliWrapper.effectiveDiscount = qli.SBQQ__TotalDiscountRate__c != null ? qli.SBQQ__TotalDiscountRate__c : 0;
                    qliWrapper.netPrice = qli.SBQQ__NetPrice__c != null ? qli.SBQQ__NetPrice__c : 0;
                    
                    if(!groupToQuoteLineSummaryMap.containsKey(qli.Group_Label__c)) {
                        qls.site = qli.Group_Label__c;
                        qls.summary = new QuoteAndLineDetail();
                        qls.quoteLineList = new List<QuoteAndLineDetail>();
                        
                        qls.summary.listPrice = 0;
                        qls.summary.discountAmount = 0;
                        qls.summary.effectiveDiscount = 0;
                        qls.summary.netPrice = 0;
                        
                        groupToQuoteLineSummaryMap.put(qli.Group_Label__c, qls);
                    }
                    
                    qls = groupToQuoteLineSummaryMap.get(qli.Group_Label__c);
                    qls.summary.listPrice += qliWrapper.listPrice;
                    qls.summary.discountAmount += qliWrapper.discountAmount;
                    qls.summary.effectiveDiscount = qls.summary.listPrice == 0 ? 0 : ((qls.summary.discountAmount/qls.summary.listPrice)*100).setScale(2, RoundingMode.HALF_UP);
                    qls.summary.netPrice = qls.summary.listPrice == 0 ? 0 : qls.summary.listPrice - qls.summary.discountAmount;
                    qls.quoteLineList.add(qliWrapper);
                    
                    groupToQuoteLineSummaryMap.put(qli.Group_Label__c, qls);
                }
                
                approvalDetails.quoteLineSummaryList = groupToQuoteLineSummaryMap.values();
                quoteLineTable1.approvalDetailsList.add(approvalDetails);
            }
            
            system.debug('<DEBUG>  quoteLineTable1 ' + quoteLineTable1);
            return quoteLineTable1;
        }
    }
    
    public static Boolean isNumeric(String s){
        try {
            Decimal.valueOf(s);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
    
    public static Boolean isBoolean(String s){
        if(s.toLowerCase() == 'false' || s.toLowerCase() == 'true')
            return true;
        else
            return false;
    }
    
    public void test1() {
        system.debug(quoteLineTableDetails);
        system.debug(isNumeric('1'));
        system.debug(isBoolean('a'));
    }
}