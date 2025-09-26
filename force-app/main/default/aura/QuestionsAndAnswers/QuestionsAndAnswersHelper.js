({
    fetchQuestionsAndAnswers : function(component, helper) {
        let action = component.get('c.getQuestionsAndAnswers');
        action.setCallback(this, $A.getCallback(function (response) {
            let state = response.getState();
            if (state === "SUCCESS") {
                let questionsAndAnswers = response.getReturnValue();
                console.log(JSON.stringify(questionsAndAnswers));
                if(questionsAndAnswers.isSuccess == true){
                    component.set('v.error', '');
                    component.set('v._questionsAndAnswers', questionsAndAnswers);
                } else {
                    component.set('v.error', questionsAndAnswers.message);
                }
            } else if (state === "ERROR") {
                let errorMessage = '';
                for(let error of response.getError()){
                    errorMessage += error.message;
                }
                component.set('v.error', errorMessage);
            }
            component.set('v._isLoaded', true);
        }));
        $A.enqueueAction(action);
    }, 
    
    callSaveProductsToQuote : function(component, event, helper, addAnotherProduct) {
        let action = component.get('c.saveProductsToQuote');
        let selectedProducts = [];
        for(let answer of component.get('v._selectedProducts')){
            if(!$A.util.isUndefinedOrNull(answer.Product__c)){
                selectedProducts.push(answer.Product__c);
            } else if(!$A.util.isUndefinedOrNull(answer.Products__c)){
                selectedProducts.push(answer.Products__c);
            }
        }
        action.setParams({
            'quoteId' : component.get('v.recordId'),
            'products' : selectedProducts
        });
        action.setCallback(this, $A.getCallback(function (response) {
            let state = response.getState();
            if (state === "SUCCESS") {
                let dmlResponse = response.getReturnValue();
                console.log(JSON.stringify(dmlResponse));
                if(dmlResponse.isSuccess == true){
                    component.set('v.error', '');
                    if(addAnotherProduct){
                        component.set('v._message', 'The Selected Products have been added to the Quote.');
                        component.set('v._previousStates', []);
                        component.set('v._previousStages', ['start']);
                        component.set('v._stage', 'start');
                        component.set('v._isAnswerSelected', false);
                        component.set('v._isLoaded', true);
                        
                        let processTypes = component.get('v._questionsAndAnswers.processTypes')
                        for(let processType of processTypes){
                            processType.selected = false;
                        }
                        component.set('v._questionsAndAnswers.processTypes', processTypes);
                        
                        window.setTimeout($A.getCallback(function() {
                            component.set('v._message', '');
                        }), 2500);
                        
                    } else {
                        var resultsToast = $A.get("e.force:showToast");
                        if($A.util.isUndefinedOrNull(resultsToast)){
                            //window.alert('Success - The Selected Products have been added to the Quote.');
                        } else {
                            resultsToast.setParams({
                                "title": "Success",
                                "message": 'The Selected Products have been added to the Quote.',
                                "type": "success",
                                "mode": "dismissible"
                            });
                            resultsToast.fire();
                        }
                        helper.redirectToQuote(component);
                    }
                } else {
                    component.set('v.error', dmlResponse.message);
                    component.set('v._isLoaded', true);
                }
            } else if (state === "ERROR") {
                let errorMessage = '';
                for(let error of response.getError()){
                    errorMessage += error.message;
                }
                component.set('v.error', errorMessage);
                component.set('v._isLoaded', true);
            }
        }));
        $A.enqueueAction(action);
    },
    
    redirectToQuote : function(component){
        let url = '/apex/SBQQ__sb?id=' + component.get('v.recordId');
        let urlEvent = $A.get("e.force:navigateToURL");
        if($A.util.isUndefinedOrNull(urlEvent)){
            document.getElementById('link').click();
            //window.location.href = url;
        } else {
            urlEvent.setParams({
                "url": url
            });
            urlEvent.fire();
        }
    },
    
    closeWindow : function(component){
        let closeQuickAction = $A.get("e.force:closeQuickAction");
        if($A.util.isUndefinedOrNull(closeQuickAction)){
            document.getElementById('link').click();
            //window.location.href = '/apex/SBQQ__sb?id=' + component.get('v.recordId');
        } else {
            closeQuickAction.fire();
        }
    }
})