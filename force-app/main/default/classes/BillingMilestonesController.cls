public with sharing class BillingMilestonesController {
    
    /**
     * @description Get project details
     * @param projectId The ID of the project record
     * @return Project__c Project record
     */
    @AuraEnabled(cacheable=true)
    public static project_cloud__Project__c getProjectDetails(Id projectId) {
        if (projectId == null) {
            System.debug('getProjectDetails called with null projectId.');
            return null; 
        }
        return [
            SELECT Id, Name, ccpe_ocp__Opportunity__c 
            FROM project_cloud__Project__c 
            WHERE Id = :projectId
            LIMIT 1
        ];
    }
    
    /**
     * @description Get orders related to the project
     * @param projectId The ID of the project record
     * @return List<Order> Order records with milestone counts
     */
    @AuraEnabled(cacheable=true)
    public static List<Order> getProjectOrders(Id projectId) {
        if (projectId == null) {
            System.debug('getProjectOrders called with null projectId.');
            return new List<Order>();
        }
        System.debug('Getting orders for project: ' + projectId);
        
        List<Order> orders = [
            SELECT Id, OrderNumber, Status, EffectiveDate, Number_of_Milestones__c
            FROM Order
            WHERE Project__c = :projectId
            ORDER BY OrderNumber ASC
        ];
        
        System.debug('Found ' + orders.size() + ' orders');
        return orders;
    }
    
    /**
     * @description Get opportunity products by order, including their milestone allocations.
     * Filters out products where Revenue_Group_Formula__c is blank.
     * @param projectId The ID of the project record
     * @return List<OrderWrapper> Opportunity products grouped by order and family
     */
    @AuraEnabled(cacheable=true)
    public static List<OrderWrapper> getOpportunityProductsByOrder(Id projectId) {
        if (projectId == null) {
            System.debug('getOpportunityProductsByOrder called with null projectId.');
            return new List<OrderWrapper>();
        }
        System.debug('Getting opportunity products by order for project: ' + projectId);
        
        project_cloud__Project__c project;
        try {
            project = [
                SELECT ccpe_ocp__Opportunity__c 
                FROM project_cloud__Project__c 
                WHERE Id = :projectId
                LIMIT 1
            ];
        } catch (QueryException e) {
            System.debug('QueryException while fetching project: ' + e.getMessage());
            throw new AuraHandledException('Could not retrieve project details. ' + e.getMessage());
        }
        
        if (project == null || project.ccpe_ocp__Opportunity__c == null) {
            System.debug('Project or Project Opportunity ID is null. ProjectId: ' + projectId);
            return new List<OrderWrapper>();
        }
        System.debug('Project Opportunity ID: ' + project.ccpe_ocp__Opportunity__c);
        
        List<Order> orders = [
            SELECT Id, OrderNumber, Status, EffectiveDate, Number_of_Milestones__c
            FROM Order
            WHERE Project__c = :projectId
            ORDER BY OrderNumber ASC
        ];
        
        System.debug('Found ' + orders.size() + ' orders for project ' + projectId);
        
        Map<Id, Order> orderMap = new Map<Id, Order>();
        for (Order ord : orders) {
            orderMap.put(ord.Id, ord);
        }
        
        if (orders.isEmpty()) {
            System.debug('No orders found for project ' + projectId + ', returning empty list');
            return new List<OrderWrapper>();
        }
        
        List<OpportunityLineItem> allOpportunityProducts = [
            SELECT Id, Name, ProductCode, Product2Id, Product2.Name, Product2.Family, 
                   UnitPrice, Quantity, TotalPrice, Description, Order_ID__c,
                   Revenue_Group_Formula__c 
            FROM OpportunityLineItem
            WHERE OpportunityId = :project.ccpe_ocp__Opportunity__c
            AND Order_ID__c IN :orderMap.keySet()
            ORDER BY Order_ID__c, Product2.Family, Product2.Name
        ];
        System.debug('Found ' + allOpportunityProducts.size() + ' total opportunity products before filtering.');

        List<OpportunityLineItem> opportunityProducts = new List<OpportunityLineItem>();
        for(OpportunityLineItem oli : allOpportunityProducts) {
            if(String.isNotBlank(oli.Revenue_Group_Formula__c)) {
                opportunityProducts.add(oli);
            }
        }
        System.debug('Found ' + opportunityProducts.size() + ' opportunity products after filtering by Revenue_Group_Formula__c.');
        
        Set<Id> oliIds = new Set<Id>();
        for(OpportunityLineItem oli : opportunityProducts){ 
            oliIds.add(oli.Id);
        }

        Map<String, project_cloud__Invoice__c> parentInvoiceMap = new Map<String, project_cloud__Invoice__c>();
        List<project_cloud__Invoice__c> existingParentInvoices = [
            SELECT Id, Order__c, Milestone_Number__c, Target_Date__c, Ready_to_Invoice__c, Description__c
            FROM project_cloud__Invoice__c
            WHERE project_cloud__Project__c = :projectId AND Order__c IN :orderMap.keySet()
        ];
        for(project_cloud__Invoice__c inv : existingParentInvoices){
            if(inv.Order__c != null && inv.Milestone_Number__c != null){
                parentInvoiceMap.put(inv.Order__c + '-' + String.valueOf(inv.Milestone_Number__c), inv);
            }
        }
        System.debug('Found ' + parentInvoiceMap.size() + ' existing parent invoices mapped.');

        Map<String, project_cloud__Invoice_Line_Item__c> lineItemMap = new Map<String, project_cloud__Invoice_Line_Item__c>();
        if(!parentInvoiceMap.isEmpty() && !oliIds.isEmpty()){
            List<project_cloud__Invoice_Line_Item__c> existingLineItems = [
                SELECT Id, project_cloud__Invoice__c, Opportunity_Product__c, project_cloud__Description__c, 
                       project_cloud__Quantity__c, project_cloud__Unit_Rate__c, Percentage__c // Added Percentage__c
                FROM project_cloud__Invoice_Line_Item__c
                WHERE project_cloud__Invoice__c IN :parentInvoiceMap.values() AND Opportunity_Product__c IN :oliIds
            ];
            for(project_cloud__Invoice_Line_Item__c line : existingLineItems){
                 lineItemMap.put(line.project_cloud__Invoice__c + '-' + line.Opportunity_Product__c, line);
            }
             System.debug('Found ' + existingLineItems.size() + ' existing invoice line items.');
        }
        
        Map<Id, Map<String, List<OpportunityProductWrapper>>> productsByOrderAndFamily = new Map<Id, Map<String, List<OpportunityProductWrapper>>>();
        
        for (OpportunityLineItem oli : opportunityProducts) { 
            Id orderId = oli.Order_ID__c;
            String family = (oli.Product2 != null && oli.Product2.Family != null) ? oli.Product2.Family : 'No Family';
            
            if (!productsByOrderAndFamily.containsKey(orderId)) {
                productsByOrderAndFamily.put(orderId, new Map<String, List<OpportunityProductWrapper>>());
            }
            
            Map<String, List<OpportunityProductWrapper>> familyMap = productsByOrderAndFamily.get(orderId);
            if (!familyMap.containsKey(family)) {
                familyMap.put(family, new List<OpportunityProductWrapper>());
            }
            
            OpportunityProductWrapper wrapper = new OpportunityProductWrapper();
            wrapper.product = oli; 
            wrapper.productId = oli.Id; 
            wrapper.allocatedPercentage = 0; 
            wrapper.milestoneAllocations = new List<MilestoneAllocation>();
            
            Order relatedOrder = orderMap.get(orderId);
            Integer milestoneCount = (relatedOrder != null && relatedOrder.Number_of_Milestones__c != null) ? Integer.valueOf(relatedOrder.Number_of_Milestones__c) : 0;
            
            for (Integer i = 1; i <= milestoneCount; i++) {
                MilestoneAllocation allocation = new MilestoneAllocation(); 
                allocation.milestoneNumber = i;
                
                project_cloud__Invoice__c parentInvoice = parentInvoiceMap.get(orderId + '-' + i);
                allocation.invoiceId = (parentInvoice != null) ? parentInvoice.Id : null; 

                project_cloud__Invoice_Line_Item__c lineItem = null;
                if (parentInvoice != null) {
                    lineItem = lineItemMap.get(parentInvoice.Id + '-' + oli.Id);
                }

                if (lineItem != null) {
                    allocation.percentage = lineItem.Percentage__c != null ? lineItem.Percentage__c : 0; // Get percentage from line item
                    allocation.amount = lineItem.project_cloud__Unit_Rate__c != null ? lineItem.project_cloud__Unit_Rate__c : 0; 
                } else {
                    allocation.percentage = 0; // Default for new potential line item
                    allocation.amount = 0;
                }
                
                allocation.description = parentInvoice != null ? parentInvoice.Description__c : '';
                allocation.targetDate = (parentInvoice != null) ? parentInvoice.Target_Date__c : null;
                allocation.readyToInvoice = (parentInvoice != null) ? parentInvoice.Ready_to_Invoice__c : false;
                
                if(allocation.percentage != null) { 
                    wrapper.allocatedPercentage += allocation.percentage;
                }
                wrapper.milestoneAllocations.add(allocation);
            }
            familyMap.get(family).add(wrapper);
        }
        
        List<OrderWrapper> result = new List<OrderWrapper>();
        for (Id orderId : orderMap.keySet()) { 
            Order currentOrder = orderMap.get(orderId);
            OrderWrapper orderWrapper = new OrderWrapper();
            orderWrapper.order = currentOrder;
            orderWrapper.productFamilies = new List<ProductFamilyWrapper>();
            
            Integer currentOrderMilestoneCount = currentOrder.Number_of_Milestones__c != null ? Integer.valueOf(currentOrder.Number_of_Milestones__c) : 0;
            orderWrapper.editableNumberOfMilestones = currentOrderMilestoneCount > 0 ? currentOrderMilestoneCount : 1; 
            orderWrapper.milestoneHeaders = new List<MilestoneHeader>();
             for (Integer i = 1; i <= currentOrderMilestoneCount; i++) {
                MilestoneHeader header = new MilestoneHeader();
                header.index = i;
                header.label = 'M' + i;
                project_cloud__Invoice__c parentInv = parentInvoiceMap.get(orderId + '-' + i);
                if(parentInv != null){
                    header.columnTargetDate = parentInv.Target_Date__c; 
                    header.columnReadyToInvoice = parentInv.Ready_to_Invoice__c;
                    header.columnDescription = parentInv.Description__c; 
                } else {
                    header.columnTargetDate = null; 
                    header.columnReadyToInvoice = false;
                    header.columnDescription = ''; 
                }
                orderWrapper.milestoneHeaders.add(header);
            }

            if (productsByOrderAndFamily.containsKey(orderId)) {
                Map<String, List<OpportunityProductWrapper>> familyMap = productsByOrderAndFamily.get(orderId);
                for (String familyNameKey : familyMap.keySet()) { 
                    ProductFamilyWrapper familyWrapper = new ProductFamilyWrapper();
                    familyWrapper.familyName = familyNameKey;
                    List<OpportunityProductWrapper> productsInFamily = familyMap.get(familyNameKey);
                    if(productsInFamily != null && !productsInFamily.isEmpty()){
                        familyWrapper.products = productsInFamily;
                        orderWrapper.productFamilies.add(familyWrapper);
                    }
                }
            }
            result.add(orderWrapper);
        }
        
        System.debug('Returning ' + result.size() + ' order wrappers after product filtering.');
        return result;
    }
    
    @AuraEnabled
    public static String saveMilestoneAllocations(Id projectId, String allocationData) {
        if (projectId == null || String.isBlank(allocationData)) {
             throw new AuraHandledException('Project ID or allocation data cannot be null/empty.');
        }
        System.debug('saveMilestoneAllocations called. ProjectId: ' + projectId);
        System.debug('Received allocationData (LWC structure): ' + allocationData);

        List<ProductSaveWrapper> lwcProductAllocations = (List<ProductSaveWrapper>) JSON.deserialize(
            allocationData, 
            List<ProductSaveWrapper>.class
        );
        
        if (lwcProductAllocations == null || lwcProductAllocations.isEmpty()) {
            return 'No allocation data received to save.';
        }

        Map<Id, OpportunityLineItem> oliMap = new Map<Id, OpportunityLineItem>();
        Set<Id> productIds = new Set<Id>();
        for (ProductSaveWrapper prodWrap : lwcProductAllocations) {
            productIds.add(prodWrap.productId);
        }
        if (!productIds.isEmpty()) {
            for (OpportunityLineItem oli : [SELECT Id, Order_ID__c, Product2.Name, Product2Id FROM OpportunityLineItem WHERE Id IN :productIds]) {
                oliMap.put(oli.Id, oli);
            }
        }
        System.debug('Fetched ' + oliMap.size() + ' OpportunityLineItems for processing.');

        Map<String, project_cloud__Invoice__c> parentInvoicesToUpsert = new Map<String, project_cloud__Invoice__c>(); 
        List<InvoiceLineItemPlaceholder> lineItemPlaceholders = new List<InvoiceLineItemPlaceholder>();

        for (ProductSaveWrapper prodWrap : lwcProductAllocations) {
            OpportunityLineItem currentOli = oliMap.get(prodWrap.productId);
            if (currentOli == null || currentOli.Order_ID__c == null) {
                System.debug('Skipping product ' + prodWrap.productId + ' due to missing OLI data or Order_ID__c.');
                continue;
            }
            Id orderId = currentOli.Order_ID__c;

            if (prodWrap.allocations == null) continue;

            for (MilestoneAllocation lwcAlloc : prodWrap.allocations) {
                String parentInvoiceKey = orderId + '-' + lwcAlloc.milestoneNumber;
                project_cloud__Invoice__c parentInvoice;

                if (parentInvoicesToUpsert.containsKey(parentInvoiceKey)) {
                    parentInvoice = parentInvoicesToUpsert.get(parentInvoiceKey);
                } else {
                    parentInvoice = new project_cloud__Invoice__c();
                    if (String.isNotBlank(lwcAlloc.invoiceId)) { 
                        parentInvoice.Id = lwcAlloc.invoiceId;
                    }
                    parentInvoice.project_cloud__Project__c = projectId;
                    parentInvoice.Order__c = orderId; 
                    parentInvoice.Milestone_Number__c = lwcAlloc.milestoneNumber;
                    parentInvoicesToUpsert.put(parentInvoiceKey, parentInvoice);
                }
                parentInvoice.Target_Date__c = lwcAlloc.targetDate;
                parentInvoice.Ready_to_Invoice__c = lwcAlloc.readyToInvoice == null ? false : lwcAlloc.readyToInvoice;
                parentInvoice.Description__c = lwcAlloc.description; 

                if(lwcAlloc.amount != null && lwcAlloc.amount > 0) { 
                    InvoiceLineItemPlaceholder ilip = new InvoiceLineItemPlaceholder();
                    ilip.parentInvoiceKey = parentInvoiceKey;
                    ilip.oliId = prodWrap.productId;
                    ilip.taskName = currentOli.Product2 != null ? currentOli.Product2.Name : currentOli.Name;
                    ilip.unitRate = lwcAlloc.amount;
                    ilip.quantity = 1; 
                    ilip.percentage = lwcAlloc.percentage; // Store percentage for line item
                    ilip.milestoneNumber = lwcAlloc.milestoneNumber;
                    lineItemPlaceholders.add(ilip);
                }
            }
        }
        
        List<project_cloud__Invoice__c> finalParentInvoices = parentInvoicesToUpsert.values();
        List<Database.UpsertResult> parentUpsertResults = new List<Database.UpsertResult>();
        if(!finalParentInvoices.isEmpty()){
            System.debug('Upserting ' + finalParentInvoices.size() + ' parent invoices.');
            parentUpsertResults = Database.upsert(finalParentInvoices, false);
        }

        Integer parentSuccessCount = 0;
        String firstParentErrorMessage = '';
        for(Database.UpsertResult ur : parentUpsertResults){
            if(ur.isSuccess()){
                parentSuccessCount++;
            } else {
                for(Database.Error err : ur.getErrors()){
                    if(String.isBlank(firstParentErrorMessage)) firstParentErrorMessage = err.getMessage();
                    System.debug('Parent Invoice Upsert Error: ' + err.getMessage());
                }
            }
        }
        if(parentSuccessCount < finalParentInvoices.size()){
            throw new AuraHandledException('Failed to save some parent invoices. First error: ' + firstParentErrorMessage);
        }
        
        for(project_cloud__Invoice__c savedParent : finalParentInvoices){
            if(savedParent.Order__c != null && savedParent.Milestone_Number__c != null){
                 parentInvoicesToUpsert.put(savedParent.Order__c + '-' + String.valueOf(savedParent.Milestone_Number__c), savedParent);
            }
        }

        List<project_cloud__Invoice_Line_Item__c> lineItemsToUpsert = new List<project_cloud__Invoice_Line_Item__c>();
        Set<String> processedLineItemKeys = new Set<String>(); 

        Set<Id> upsertedParentInvoiceIds = new Set<Id>();
        for(project_cloud__Invoice__c pInv : finalParentInvoices) upsertedParentInvoiceIds.add(pInv.Id);
        
        Map<String, project_cloud__Invoice_Line_Item__c> existingLineItemsMap = new Map<String, project_cloud__Invoice_Line_Item__c>();
        if(!upsertedParentInvoiceIds.isEmpty() && !productIds.isEmpty()){
            for(project_cloud__Invoice_Line_Item__c li : [
                SELECT Id, project_cloud__Invoice__c, Opportunity_Product__c 
                FROM project_cloud__Invoice_Line_Item__c 
                WHERE project_cloud__Invoice__c IN :upsertedParentInvoiceIds AND Opportunity_Product__c IN :productIds
            ]){
                existingLineItemsMap.put(li.project_cloud__Invoice__c + '-' + li.Opportunity_Product__c, li);
            }
        }

        for(InvoiceLineItemPlaceholder ilip : lineItemPlaceholders){
            project_cloud__Invoice__c parentInv = parentInvoicesToUpsert.get(ilip.parentInvoiceKey);
            if(parentInv == null || parentInv.Id == null) {
                System.debug('Skipping line item, parent invoice not found or not saved for key: ' + ilip.parentInvoiceKey);
                continue;
            }

            String lineItemMapKey = parentInv.Id + '-' + ilip.oliId;
            project_cloud__Invoice_Line_Item__c lineItem = existingLineItemsMap.get(lineItemMapKey);

            if(lineItem == null){
                lineItem = new project_cloud__Invoice_Line_Item__c();
            }
            
            lineItem.project_cloud__Invoice__c = parentInv.Id; 
            lineItem.Opportunity_Product__c = ilip.oliId; 
            lineItem.project_cloud__Description__c = ilip.taskName;
            lineItem.project_cloud__Quantity__c = ilip.quantity;
            lineItem.project_cloud__Unit_Rate__c = ilip.unitRate;
            lineItem.Percentage__c = ilip.percentage; // Save percentage to line item
            
            lineItemsToUpsert.add(lineItem);
            processedLineItemKeys.add(lineItemMapKey);
        }

        List<project_cloud__Invoice_Line_Item__c> lineItemsToDelete = new List<project_cloud__Invoice_Line_Item__c>();
        for(String existingKey : existingLineItemsMap.keySet()){
            if(!processedLineItemKeys.contains(existingKey)){
                lineItemsToDelete.add(existingLineItemsMap.get(existingKey));
            }
        }
        if(!lineItemsToDelete.isEmpty()){
            System.debug('Deleting ' + lineItemsToDelete.size() + ' orphaned line items.');
            Database.delete(lineItemsToDelete, false);
        }

        List<Database.UpsertResult> lineItemUpsertResults = new List<Database.UpsertResult>();
        if(!lineItemsToUpsert.isEmpty()){
            System.debug('Upserting ' + lineItemsToUpsert.size() + ' invoice line items.');
            lineItemUpsertResults = Database.upsert(lineItemsToUpsert, false);
        }
        
        Integer lineItemSuccessCount = 0;
        String firstLineItemErrorMessage = '';
        for(Database.UpsertResult ur : lineItemUpsertResults){
            if(ur.isSuccess()){
                lineItemSuccessCount++;
            } else {
                 for(Database.Error err : ur.getErrors()){
                    if(String.isBlank(firstLineItemErrorMessage)) firstLineItemErrorMessage = err.getMessage();
                    System.debug('Line Item Upsert Error: ' + err.getMessage());
                }
            }
        }
        if(lineItemSuccessCount < lineItemsToUpsert.size()){
             throw new AuraHandledException('Failed to save some invoice line items. First error: ' + firstLineItemErrorMessage);
        }

        return 'Successfully processed ' + parentSuccessCount + ' invoices and ' + lineItemSuccessCount + ' line items.';
    }

    private class InvoiceLineItemPlaceholder {
        String parentInvoiceKey;
        Id oliId;
        String taskName;
        Decimal unitRate;
        Decimal quantity;
        Decimal percentage; // Added percentage
        Integer milestoneNumber;
    }

    @AuraEnabled
    public static String updateOrderMilestoneCount(Id orderId, Integer newCount) {
        if (orderId == null) {
            throw new AuraHandledException('Order ID cannot be null.');
        }
        if (newCount == null || newCount < 0) { 
            throw new AuraHandledException('New milestone count cannot be null or negative.');
        }
        System.debug('Updating milestone count for Order ID: ' + orderId + ' to ' + newCount);

        try {
            Order ord = [SELECT Id, Number_of_Milestones__c FROM Order WHERE Id = :orderId LIMIT 1];
            // Consider implications if newCount is less than existing milestones with line items.
            // For now, just updating the count. LWC will handle display.
            // Logic to delete/archive orphaned Invoices/LineItems could be added here if needed.
            ord.Number_of_Milestones__c = newCount;
            update ord;
            return 'Milestone count updated successfully for Order ' + ord.Id + '.';
        } catch (DmlException e) {
            System.debug('DML Exception updating order milestone count: ' + e.getMessage());
            throw new AuraHandledException('Failed to update milestone count: ' + e.getMessage());
        } catch (QueryException e) {
            System.debug('Query Exception finding order for milestone count update: ' + e.getMessage());
            throw new AuraHandledException('Could not find the order to update: ' + e.getMessage());
        } catch (Exception e) {
            System.debug('General Exception updating order milestone count: ' + e.getMessage());
            throw new AuraHandledException('An unexpected error occurred: ' + e.getMessage());
        }
    }
    
    // Wrapper classes for data structure
    
    public class ProductSaveWrapper {
        @AuraEnabled public Id productId; 
        @AuraEnabled public List<MilestoneAllocation> allocations; 
    }

    public class OrderWrapper {
        @AuraEnabled public Order order;
        @AuraEnabled public List<ProductFamilyWrapper> productFamilies;
        @AuraEnabled public List<MilestoneHeader> milestoneHeaders; 
        @AuraEnabled public Integer totalColumns;
        @AuraEnabled public List<MilestoneTotal> milestoneTotals;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Boolean hasProducts;
        @AuraEnabled public Boolean isExpanded; 
        @AuraEnabled public String sectionClass; 
        @AuraEnabled public Integer editableNumberOfMilestones; 
    }
    
    public class ProductFamilyWrapper {
        @AuraEnabled public String familyName;
        @AuraEnabled public List<OpportunityProductWrapper> products;
    }
    
    public class OpportunityProductWrapper {
        @AuraEnabled public OpportunityLineItem product; 
        @AuraEnabled public Id productId; 
        @AuraEnabled public Decimal allocatedPercentage;
        @AuraEnabled public List<MilestoneAllocation> milestoneAllocations; 
        @AuraEnabled public Decimal remainingPercentage;
        @AuraEnabled public String remainingStyling;
    }
    
    public class MilestoneAllocation {
        @AuraEnabled public Integer milestoneNumber;
        @AuraEnabled public Decimal percentage; // This will now be for Invoice_Line_Item__c.Percentage__c
        @AuraEnabled public Decimal amount; // This will be Invoice_Line_Item__c.Unit_Rate__c
        @AuraEnabled public Id invoiceId; // ID of the PARENT Invoice for this column
        @AuraEnabled public Date targetDate; // Column-level target date for PARENT Invoice       
        @AuraEnabled public Boolean readyToInvoice; // Column-level ready for PARENT Invoice
        @AuraEnabled public String description; // Column-level description for PARENT Invoice
    }

    public class MilestoneHeader {
        @AuraEnabled public Integer index;
        @AuraEnabled public String label;
        @AuraEnabled public Date columnTargetDate;
        @AuraEnabled public Boolean columnReadyToInvoice;
        @AuraEnabled public String columnDescription; 
        @AuraEnabled public Boolean isEffectivelyLocked; 
        @AuraEnabled public String headerClass; 
        @AuraEnabled public String cellClass; 
    }

    public class MilestoneTotal {
        @AuraEnabled public Integer milestone;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String cellClass; 
    }
}