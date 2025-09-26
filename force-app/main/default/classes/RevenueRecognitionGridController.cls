public with sharing class RevenueRecognitionGridController {

    // Wrapper for the top-level "Super Group"
    public class SuperGroupDisplay implements Comparable {
        @AuraEnabled public String groupName { get; set; }
        @AuraEnabled public List<ProductFamilyDisplay> productFamilies { get; set; }
        @AuraEnabled public Map<String, Decimal> monthlySuperGroupTotals { get; set; }
        private Integer sortOrder;

        public SuperGroupDisplay(String name, Integer order) {
            this.groupName = name;
            this.productFamilies = new List<ProductFamilyDisplay>();
            this.monthlySuperGroupTotals = new Map<String, Decimal>();
            this.sortOrder = order;
        }

        public Integer compareTo(Object compareTo) {
            SuperGroupDisplay compareToSG = (SuperGroupDisplay)compareTo;
            return this.sortOrder - compareToSG.sortOrder;
        }
    }

    // Wrapper class for the entire dataset returned to LWC
    public class RevenueGridData {
        @AuraEnabled public List<String> uniqueMonths { get; set; }
        @AuraEnabled public List<SuperGroupDisplay> superGroups { get; set; }
        @AuraEnabled public Date projectCalculatedStartDate { get; set; }
        @AuraEnabled public Date projectCalculatedEndDate { get; set; }
        @AuraEnabled public Map<String, Decimal> monthlyGrandTotals { get; set; }

        public RevenueGridData() {
            this.uniqueMonths = new List<String>();
            this.superGroups = new List<SuperGroupDisplay>();
            this.monthlyGrandTotals = new Map<String, Decimal>();
        }
    }

    // ProductFamilyDisplay remains the same
    public class ProductFamilyDisplay implements Comparable {
        @AuraEnabled public String familyName { get; set; }
        @AuraEnabled public List<ProductCodeDisplay> productCodes { get; set; }
        @AuraEnabled public Map<String, Decimal> monthlyFamilyTotals { get; set; }

        public ProductFamilyDisplay(String name) { this.familyName = name; this.productCodes = new List<ProductCodeDisplay>(); this.monthlyFamilyTotals = new Map<String, Decimal>(); }
        public Integer compareTo(Object compareTo) { return this.familyName.compareTo(((ProductFamilyDisplay)compareTo).familyName); }
    }

    // ProductCodeDisplay now includes forecastTotal
    public class ProductCodeDisplay implements Comparable {
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public Map<String, Decimal> monthlyAmounts { get; set; }
        @AuraEnabled public Decimal soldPrice { get; set; }
        @AuraEnabled public Decimal forecastTotal { get; set; }

        public ProductCodeDisplay(String code) {
            this.productCode = code;
            this.monthlyAmounts = new Map<String, Decimal>();
            this.soldPrice = 0;
            this.forecastTotal = 0;
        }
        public Integer compareTo(Object compareTo) { return this.productCode.compareTo(((ProductCodeDisplay)compareTo).productCode); }
    }

    // --- Main Data Fetch Method ---
    @AuraEnabled(cacheable=true)
    public static RevenueGridData getRevenueRecognitionGridData(Id projectId) {
        RevenueGridData gridData = new RevenueGridData();
        if (String.isBlank(projectId)) return gridData;

        project_cloud__Project__c currentProject = getCurrentProject(projectId);
        if(currentProject == null) return gridData;
        
        gridData.projectCalculatedStartDate = currentProject.project_cloud__Calculated_Start__c;
        gridData.projectCalculatedEndDate = currentProject.project_cloud__Calculated_End__c;
        
        Date effectiveGridStartDate = gridData.projectCalculatedStartDate;
        Date effectiveGridEndDate = gridData.projectCalculatedEndDate;

        Map<String, SuperGroupDisplay> superGroupMap = initializeSuperGroupMap();

        // 1. Process Existing Revenue Recognition records
        List<project_cloud__Revenue_Recognition__c> revRecs = [
            SELECT Id, project_cloud__Amount__c, project_cloud__Date__c, Product_Family__c, Product_Code__c, project_cloud__Project__c
            FROM project_cloud__Revenue_Recognition__c
            WHERE project_cloud__Project__c = :projectId AND project_cloud__Date__c != NULL
            ORDER BY Product_Family__c, Product_Code__c, project_cloud__Date__c
        ];

        for (project_cloud__Revenue_Recognition__c rr : revRecs) {
            if (rr.project_cloud__Date__c != null) {
                if (effectiveGridStartDate == null || rr.project_cloud__Date__c < effectiveGridStartDate) effectiveGridStartDate = rr.project_cloud__Date__c;
                if (effectiveGridEndDate == null || rr.project_cloud__Date__c > effectiveGridEndDate) effectiveGridEndDate = rr.project_cloud__Date__c;

                String productCode = String.isBlank(rr.Product_Code__c) ? '(Blank Product Code)' : rr.Product_Code__c;
                String productFamily = String.isBlank(rr.Product_Family__c) ? '(Blank Product Family)' : rr.Product_Family__c;
                String superGroupName = getSuperGroupName(productCode);

                SuperGroupDisplay superGroup = superGroupMap.get(superGroupName);
                ProductFamilyDisplay familyDisplay = getOrCreateFamilyDisplay(superGroup, productFamily);
                ProductCodeDisplay codeDisplay = getOrCreateProductCodeDisplay(familyDisplay, productCode);

                String monthYearKey = rr.project_cloud__Date__c.year() + '-' + String.valueOf(rr.project_cloud__Date__c.month()).leftPad(2, '0');
                Decimal amount = rr.project_cloud__Amount__c == null ? 0 : rr.project_cloud__Amount__c;
                
                aggregateAmounts(codeDisplay, familyDisplay, superGroup, monthYearKey, amount);
            }
        }
        
        // 2. Pre-fetch all necessary data for forecasting
        List<project_cloud__Project_Task__c> allTasksForForecast = getTasksForForecast(projectId);
        Map<String, List<project_cloud__Resource_Assignment__c>> taskToAssignmentsMap = getResourceAssignments(allTasksForForecast);
        Map<Id, List<project_cloud__Invoice_Line_Item__c>> oppProductToMilestonesMap = getMilestoneData(projectId);

        // 3. Process tasks for forecasting
        for (project_cloud__Project_Task__c task : allTasksForForecast) {
            String productCode = task.Name;
            String productFamily = String.isBlank(task.Product_Family__c) ? '(Default Task Family)' : task.Product_Family__c;
            String superGroupName = getSuperGroupName(productCode);
            
            SuperGroupDisplay superGroup = superGroupMap.get(superGroupName);
            if (superGroup == null) continue;

            ProductFamilyDisplay familyDisplay = getOrCreateFamilyDisplay(superGroup, productFamily);
            ProductCodeDisplay codeDisplay = getOrCreateProductCodeDisplay(familyDisplay, productCode);

            if (task.Price_Rev_Sold__c != null) {
                codeDisplay.soldPrice = task.Price_Rev_Sold__c;
            }
            
            // Route to the correct forecasting logic based on super group
            if ('Software'.equalsIgnoreCase(superGroupName) || '3rd Party Fees'.equalsIgnoreCase(superGroupName) || 'Customized Software'.equalsIgnoreCase(superGroupName)) {
                effectiveGridEndDate = processMilestoneForecast(task, oppProductToMilestonesMap.get(task.Opportunity_Product__c), codeDisplay, familyDisplay, superGroup, effectiveGridEndDate);
            }
            else if (task.Code__c == 'MT' || task.Code__c == 'MS') {
                effectiveGridEndDate = processMtMsForecast(task, currentProject, codeDisplay, familyDisplay, superGroup, effectiveGridEndDate);
            } else if ('Professional Services'.equalsIgnoreCase(productFamily)) {
                effectiveGridEndDate = processPsForecast(task, taskToAssignmentsMap.get(task.Id), codeDisplay, familyDisplay, superGroup, effectiveGridEndDate);
            }
        }
        
        // 4. Finalize Dates, Totals, and Sorting
        gridData.uniqueMonths = generateMonthList(effectiveGridStartDate, effectiveGridEndDate);
        gridData.superGroups.addAll(superGroupMap.values());
        gridData.superGroups.sort();
        finalizeAndCalculateTotals(gridData);
        
        return gridData;
    }

    // --- Helper Methods ---

    private static Map<String, SuperGroupDisplay> initializeSuperGroupMap() {
        Map<String, SuperGroupDisplay> superGroupMap = new Map<String, SuperGroupDisplay>();
        superGroupMap.put('Professional Services', new SuperGroupDisplay('Professional Services', 1));
        superGroupMap.put('Managed Services', new SuperGroupDisplay('Managed Services', 2));
        superGroupMap.put('Maintenance', new SuperGroupDisplay('Maintenance', 3));
        superGroupMap.put('Software', new SuperGroupDisplay('Software', 4));
        superGroupMap.put('3rd Party Fees', new SuperGroupDisplay('3rd Party Fees', 5));
        superGroupMap.put('Customized Software', new SuperGroupDisplay('Customized Software', 6));
        superGroupMap.put('Hardware', new SuperGroupDisplay('Hardware', 7));
        superGroupMap.put('Travel/Expenses', new SuperGroupDisplay('Travel/Expenses', 8));
        superGroupMap.put('Other', new SuperGroupDisplay('Other', 99));
        return superGroupMap;
    }

    private static project_cloud__Project__c getCurrentProject(Id projectId) {
        try {
            return [
                SELECT Id, project_cloud__Calculated_Start__c, project_cloud__Calculated_End__c,
                       MT_Revenue__c, Actual_MT_Start_Date__c, MT_Term__c,
                       MS_Revenue__c, Actual_MS_Start_Date__c, MS_Term__c
                FROM project_cloud__Project__c
                WHERE Id = :projectId
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('Error in getCurrentProject: ' + e.getMessage());
            return null;
        }
    }
    
    private static List<project_cloud__Project_Task__c> getTasksForForecast(Id projectId) {
        return [
            SELECT Id, Name, Code__c, Product_Family__c, Opportunity_Product__c, project_cloud__Project_Phase__r.project_cloud__Project__c,
                   Price_Rev_Sold__c, Project_Baseline_Hours__c, POC__c
            FROM project_cloud__Project_Task__c
            WHERE project_cloud__Project_Phase__r.project_cloud__Project__c = :projectId
            AND (Code__c = 'MT' OR Code__c = 'MS' OR Product_Family__c = 'Professional Services' OR Product_Family__c = 'Software' OR Product_Family__c = '3rd Party Fees' OR Product_Family__c = 'Customized Software')
            AND Opportunity_Product__c != NULL
        ];
    }
    
    private static Map<String, List<project_cloud__Resource_Assignment__c>> getResourceAssignments(List<project_cloud__Project_Task__c> tasks) {
        Set<String> psTaskIds = new Set<String>();
        for(project_cloud__Project_Task__c task : tasks){
            if('Professional Services'.equalsIgnoreCase(task.Product_Family__c)){
                psTaskIds.add(task.Id);
            }
        }
        
        Map<String, List<project_cloud__Resource_Assignment__c>> taskToAssignmentsMap = new Map<String, List<project_cloud__Resource_Assignment__c>>();
        if(!psTaskIds.isEmpty()){
            for(project_cloud__Resource_Assignment__c ra : [
                SELECT Project_Task_CASESAFEID__c, project_cloud__Calculated_Start__c, project_cloud__Calculated_End__c, project_cloud__Calculated_Hours_Total__c
                FROM project_cloud__Resource_Assignment__c
                WHERE Project_Task_CASESAFEID__c IN :psTaskIds
                AND project_cloud__Calculated_Start__c != NULL AND project_cloud__Calculated_End__c != NULL AND project_cloud__Calculated_Hours_Total__c != NULL AND project_cloud__Calculated_Hours_Total__c > 0
            ]){
                if(!taskToAssignmentsMap.containsKey(ra.Project_Task_CASESAFEID__c)){
                    taskToAssignmentsMap.put(ra.Project_Task_CASESAFEID__c, new List<project_cloud__Resource_Assignment__c>());
                }
                taskToAssignmentsMap.get(ra.Project_Task_CASESAFEID__c).add(ra);
            }
        }
        return taskToAssignmentsMap;
    }
    
    private static Map<Id, List<project_cloud__Invoice_Line_Item__c>> getMilestoneData(Id projectId){
        Map<Id, List<project_cloud__Invoice_Line_Item__c>> oppProdIdToLinesMap = new Map<Id, List<project_cloud__Invoice_Line_Item__c>>();
        List<project_cloud__Invoice__c> parentInvoices = [
            SELECT Id, Target_Date__c 
            FROM project_cloud__Invoice__c 
            WHERE project_cloud__Project__c = :projectId AND Target_Date__c != NULL
        ];

        if(parentInvoices.isEmpty()) return oppProdIdToLinesMap;

        Map<Id, Date> invoiceIdToTargetDateMap = new Map<Id, Date>();
        for(project_cloud__Invoice__c inv : parentInvoices){
            invoiceIdToTargetDateMap.put(inv.Id, inv.Target_Date__c);
        }

        for(project_cloud__Invoice_Line_Item__c line : [
            SELECT Id, Opportunity_Product__c, project_cloud__Unit_Rate__c, project_cloud__Invoice__c
            FROM project_cloud__Invoice_Line_Item__c
            WHERE project_cloud__Invoice__c IN :invoiceIdToTargetDateMap.keySet()
            AND Opportunity_Product__c != NULL AND project_cloud__Unit_Rate__c != NULL AND project_cloud__Unit_Rate__c > 0
        ]){
            if(!oppProdIdToLinesMap.containsKey(line.Opportunity_Product__c)){
                oppProdIdToLinesMap.put(line.Opportunity_Product__c, new List<project_cloud__Invoice_Line_Item__c>());
            }
            line.project_cloud__Invoice__r = new project_cloud__Invoice__c(Target_Date__c = invoiceIdToTargetDateMap.get(line.project_cloud__Invoice__c));
            oppProdIdToLinesMap.get(line.Opportunity_Product__c).add(line);
        }
        return oppProdIdToLinesMap;
    }

    private static Date processMilestoneForecast(project_cloud__Project_Task__c task, List<project_cloud__Invoice_Line_Item__c> milestoneLines, ProductCodeDisplay codeDisplay, ProductFamilyDisplay familyDisplay, SuperGroupDisplay superGroup, Date effectiveGridEndDate) {
        if (milestoneLines == null || milestoneLines.isEmpty()) {
            System.debug('No milestone data found for task: ' + task.Name);
            return effectiveGridEndDate;
        }

        Decimal totalForecastForThisRow = 0;
        Date today = System.today().toStartOfMonth();

        for (project_cloud__Invoice_Line_Item__c line : milestoneLines) {
            Date targetDate = line.project_cloud__Invoice__r.Target_Date__c;

            if (targetDate != null && targetDate.toStartOfMonth() >= today) {
                if (effectiveGridEndDate == null || targetDate > effectiveGridEndDate) {
                    effectiveGridEndDate = targetDate;
                }
                
                String monthKey = targetDate.year() + '-' + String.valueOf(targetDate.month()).leftPad(2, '0');
                Decimal forecastAmount = line.project_cloud__Unit_Rate__c;

                if (!codeDisplay.monthlyAmounts.containsKey(monthKey)) {
                    aggregateAmounts(codeDisplay, familyDisplay, superGroup, monthKey, forecastAmount);
                    totalForecastForThisRow += forecastAmount;
                }
            }
        }
        codeDisplay.forecastTotal += totalForecastForThisRow;
        return effectiveGridEndDate;
    }

    private static Date processMtMsForecast(project_cloud__Project_Task__c task, project_cloud__Project__c project, ProductCodeDisplay codeDisplay, ProductFamilyDisplay familyDisplay, SuperGroupDisplay superGroup, Date effectiveGridEndDate) {
        Decimal totalRevenueInputForThisTask = task.Price_Rev_Sold__c;
        Date recognitionStartDate = null;
        Integer recognitionTerm = 0;

        if (task.Code__c == 'MT') {
            recognitionStartDate = project.Actual_MT_Start_Date__c;
            recognitionTerm = (project.MT_Term__c == null) ? 0 : Integer.valueOf(project.MT_Term__c);
        } else { 
            recognitionStartDate = project.Actual_MS_Start_Date__c;
            recognitionTerm = (project.MS_Term__c == null) ? 0 : Integer.valueOf(project.MS_Term__c);
        }

        if (totalRevenueInputForThisTask == null || totalRevenueInputForThisTask == 0 || recognitionStartDate == null || recognitionTerm == null || recognitionTerm == 0) return effectiveGridEndDate;
        
        Date forecastPeriodEndDate = recognitionStartDate.addMonths(recognitionTerm - 1);
        if (effectiveGridEndDate == null || forecastPeriodEndDate > effectiveGridEndDate) {
            effectiveGridEndDate = forecastPeriodEndDate;
        }
        
        Decimal alreadyRecognized = 0;
        if (codeDisplay.monthlyAmounts != null) {
            for (Decimal amount : codeDisplay.monthlyAmounts.values()) { alreadyRecognized += amount; }
        }
        
        Decimal remainingRevenue = totalRevenueInputForThisTask - alreadyRecognized;
        if (remainingRevenue <= 0) return effectiveGridEndDate;
        
        Decimal amountPerMonth = remainingRevenue / recognitionTerm;
        Decimal totalForecastForThisRow = 0;

        for (Integer i = 0; i < recognitionTerm; i++) {
            Date forecastMonthDate = recognitionStartDate.addMonths(i);
            String monthKey = forecastMonthDate.year() + '-' + String.valueOf(forecastMonthDate.month()).leftPad(2, '0');
            if (!codeDisplay.monthlyAmounts.containsKey(monthKey)) {
                aggregateAmounts(codeDisplay, familyDisplay, superGroup, monthKey, amountPerMonth);
                totalForecastForThisRow += amountPerMonth;
            }
        }
        codeDisplay.forecastTotal += totalForecastForThisRow;
        return effectiveGridEndDate;
    }

    private static Date processPsForecast(project_cloud__Project_Task__c task, List<project_cloud__Resource_Assignment__c> assignments, ProductCodeDisplay codeDisplay, ProductFamilyDisplay familyDisplay, SuperGroupDisplay superGroup, Date effectiveGridEndDate) {
        if (task.Price_Rev_Sold__c == null || task.Price_Rev_Sold__c == 0 || task.POC__c == null) return effectiveGridEndDate;

        Decimal totalTaskRevenue = task.Price_Rev_Sold__c;
        Decimal remainingRevenue = totalTaskRevenue * (1 - (task.POC__c / 100.0));
        if (remainingRevenue <= 0) return effectiveGridEndDate;
        
        if (assignments == null || assignments.isEmpty()) return effectiveGridEndDate;

        Map<String, Decimal> monthlyHours = new Map<String, Decimal>();
        Decimal totalFutureHours = 0;
        Date today = System.today().toStartOfMonth();
        Date maxRAEndDate = null;

        for (project_cloud__Resource_Assignment__c ra : assignments) {
            if (ra.project_cloud__Calculated_End__c != null && (maxRAEndDate == null || ra.project_cloud__Calculated_End__c > maxRAEndDate)) {
                maxRAEndDate = ra.project_cloud__Calculated_End__c;
            }
            Integer monthsInRA = ra.project_cloud__Calculated_Start__c.monthsBetween(ra.project_cloud__Calculated_End__c.addDays(1));
            if (monthsInRA <= 0) monthsInRA = 1;
            Decimal hoursPerMonth = ra.project_cloud__Calculated_Hours_Total__c / monthsInRA;
            Date currentMonthPointer = ra.project_cloud__Calculated_Start__c.toStartOfMonth();
            while (currentMonthPointer <= ra.project_cloud__Calculated_End__c.toStartOfMonth()) {
                String monthKey = currentMonthPointer.year() + '-' + String.valueOf(currentMonthPointer.month()).leftPad(2, '0');
                if (currentMonthPointer >= today) {
                    monthlyHours.put(monthKey, (monthlyHours.get(monthKey) == null ? 0 : monthlyHours.get(monthKey)) + hoursPerMonth);
                }
                currentMonthPointer = currentMonthPointer.addMonths(1);
            }
        }
        
        if (maxRAEndDate != null && (effectiveGridEndDate == null || maxRAEndDate > effectiveGridEndDate)) {
            effectiveGridEndDate = maxRAEndDate;
        }

        for(Decimal hours : monthlyHours.values()){ totalFutureHours += hours; }
        if(totalFutureHours == 0) return effectiveGridEndDate;

        Decimal rate = remainingRevenue / totalFutureHours;
        Decimal totalForecastForThisRow = 0;

        for(String monthKey : monthlyHours.keySet()){
            if (!codeDisplay.monthlyAmounts.containsKey(monthKey)) {
                Decimal forecastAmount = monthlyHours.get(monthKey) * rate;
                aggregateAmounts(codeDisplay, familyDisplay, superGroup, monthKey, forecastAmount);
                totalForecastForThisRow += forecastAmount;
            }
        }
        codeDisplay.forecastTotal += totalForecastForThisRow;
        return effectiveGridEndDate;
    }

    private static ProductFamilyDisplay getOrCreateFamilyDisplay(SuperGroupDisplay superGroup, String familyName) {
        for (ProductFamilyDisplay pfd : superGroup.productFamilies) {
            if (pfd.familyName.equals(familyName)) return pfd;
        }
        ProductFamilyDisplay newPfd = new ProductFamilyDisplay(familyName);
        superGroup.productFamilies.add(newPfd);
        return newPfd;
    }

    private static ProductCodeDisplay getOrCreateProductCodeDisplay(ProductFamilyDisplay family, String productCodeName) {
        for (ProductCodeDisplay pcd : family.productCodes) {
            if (pcd.productCode.equals(productCodeName)) return pcd;
        }
        ProductCodeDisplay newPcd = new ProductCodeDisplay(productCodeName);
        family.productCodes.add(newPcd);
        return newPcd;
    }
    
    private static String getSuperGroupName(String productCode) {
        if (String.isBlank(productCode)) return 'Other';
        productCode = productCode.toUpperCase();
        if (productCode.startsWith('3P')) return '3rd Party Fees';
        if (productCode.startsWith('AP') || productCode.startsWith('AE') || productCode.startsWith('CP') || productCode.startsWith('CX') || productCode.startsWith('EM')) return 'Software';
        if (productCode.startsWith('AC')) return 'Customized Software';
        if (productCode.startsWith('PS')) return 'Professional Services';
        if (productCode.startsWith('MS')) return 'Managed Services';
        if (productCode.startsWith('MT')) return 'Maintenance';
        if (productCode.startsWith('HW')) return 'Hardware';
        if (productCode.startsWith('TE')) return 'Travel/Expenses';
        return 'Other'; 
    }
    
    private static void aggregateAmounts(ProductCodeDisplay code, ProductFamilyDisplay family, SuperGroupDisplay superGroup, String monthKey, Decimal amount) {
        code.monthlyAmounts.put(monthKey, (code.monthlyAmounts.get(monthKey) == null ? 0 : code.monthlyAmounts.get(monthKey)) + amount);
        family.monthlyFamilyTotals.put(monthKey, (family.monthlyFamilyTotals.get(monthKey) == null ? 0 : family.monthlyFamilyTotals.get(monthKey)) + amount);
        superGroup.monthlySuperGroupTotals.put(monthKey, (superGroup.monthlySuperGroupTotals.get(monthKey) == null ? 0 : superGroup.monthlySuperGroupTotals.get(monthKey)) + amount);
    }
    
    private static List<String> generateMonthList(Date startDate, Date endDate) {
        List<String> months = new List<String>();
        if(startDate == null || endDate == null || startDate > endDate) return months;
        Date currentMonth = startDate.toStartOfMonth();
        while(currentMonth <= endDate.toStartOfMonth()){
            months.add(currentMonth.year() + '-' + String.valueOf(currentMonth.month()).leftPad(2, '0'));
            currentMonth = currentMonth.addMonths(1);
        }
        return months;
    }
    
    private static void finalizeAndCalculateTotals(RevenueGridData gridData) {
        for(String monthKey : gridData.uniqueMonths){
            gridData.monthlyGrandTotals.put(monthKey, 0);
        }
        for(SuperGroupDisplay sgd : gridData.superGroups){
            sgd.productFamilies.sort();
            for(ProductFamilyDisplay pfd : sgd.productFamilies){
                pfd.productCodes.sort();
                 for (String monthKey : gridData.uniqueMonths) {
                    if (!pfd.monthlyFamilyTotals.containsKey(monthKey)) pfd.monthlyFamilyTotals.put(monthKey, 0);
                    if (!sgd.monthlySuperGroupTotals.containsKey(monthKey)) sgd.monthlySuperGroupTotals.put(monthKey, 0);
                    
                    gridData.monthlyGrandTotals.put(monthKey, gridData.monthlyGrandTotals.get(monthKey) + pfd.monthlyFamilyTotals.get(monthKey));

                    for (ProductCodeDisplay pcd : pfd.productCodes) {
                        if (!pcd.monthlyAmounts.containsKey(monthKey)) pcd.monthlyAmounts.put(monthKey, 0);
                    }
                }
            }
        }
    }
}