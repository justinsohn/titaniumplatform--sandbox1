({
    init : function(component, event, helper){
        helper.fetchQuestionsAndAnswers(component, helper);
	},
    
    handleGoBack : function(component, event, helper){
        let previousStates = component.get('v._previousStates');
        previousStates.pop();
        component.set('v._previousStates', previousStates);
        let previousStages = component.get('v._previousStages');
        previousStages.pop();
        component.set('v._previousStages', previousStages);
        let stage = previousStages[previousStages.length - 1];
        component.set('v._stage', stage);
        if(stage != 'start'){
            let state = previousStates[previousStates.length - 1];
            component.set('v._questions', state);
        }
        component.set('v._isAnswerSelected', true);
    },
    
    handeProcessTypeSelectionChange : function(component, event, helper){
        let processTypes = component.get('v._questionsAndAnswers.processTypes');
        let isAnswerSelected = false;
        for(let processType of processTypes){
            if(processType.value == event.target.id){
                processType.selected = !processType.selected;
            } else {
                processType.selected = false;
            }
            if(processType.selected){
                isAnswerSelected = true;
            }
        }
        component.set('v._isAnswerSelected', isAnswerSelected);
        component.set('v._questionsAndAnswers.processTypes', processTypes);
    }, 
    
    handeSelectionChange : function(component, event, helper){
        let questions = component.get('v._questions');
        let stage = component.get('v._stage');
        let isAnswerSelected = false;
        switch(stage){
            case "question1":
                for(let question of questions){
                    for(let answer of question.Answers__r){
                        if(answer.Id == event.target.id){
                            answer.selected = !answer.selected;
                        } else {
                            if(answer.selectSingle){
                                answer.selected = false;
                            }
                        }
                        if(answer.selected){
                            isAnswerSelected = true;
                        }
                    }
                }
                break;
            case "question2":
                for(let question of questions){
                    for(let answer of question.Answer_2__r){
                        if(answer.Id == event.target.id){
                            answer.selected = !answer.selected;
                        } else {
                            if(answer.selectSingle){
                                answer.selected = false;
                            }
                        }
                        if(answer.selected){
                            isAnswerSelected = true;
                        }
                    }
                }
                break;
            case "question3":
                for(let question of questions){
                    for(let answer of question.Answer_3__r){
                        if(answer.Id == event.target.id){
                            answer.selected = !answer.selected;
                        } else {
                            if(answer.selectSingle){
                                answer.selected = false;
                            }
                        }
                        if(answer.selected){
                            isAnswerSelected = true;
                        }
                    }
                }
                break;
        }
        component.set('v._isAnswerSelected', isAnswerSelected);
        component.set('v._questions', questions);
    },
    
    handleNext : function(component, event, helper){
        let questionsAndAnswers = component.get('v._questionsAndAnswers');
        let previousStates = component.get('v._previousStates');
        let previousStages = component.get('v._previousStages');
        let stage = component.get('v._stage');
        let questions = [];
        let previousQuestions = component.get('v._questions');
        let isProductSelected = false;
        let selectedProducts = [];
        switch(stage){
            case "start":
                stage = "question1";
                console.log('handleNext: this is the start! ');
                let processTypes = component.get('v._questionsAndAnswers.processTypes');
                let selectedProcessTypes = [];
                for(let processType of processTypes){
                    if(processType.selected){
                        selectedProcessTypes.push(processType.value);
                    }
                }
                //get question1 that has a process type of value
                for(let s of Object.keys(questionsAndAnswers.question1)){
                    let question = questionsAndAnswers.question1[s];
                    if(selectedProcessTypes.includes(question.Process_Type__c)){
                        for(let answer of question.Answers__r){
                            answer.selected = false;
                            if($A.util.isUndefinedOrNull(answer.Product__c) && $A.util.isUndefinedOrNull(answer.Products__c)){
                                answer.selectSingle = true;
                            } else {
                                answer.selectSingle = false;
                            }
                        }
                        questions.push(question);
                    }
                }
                break;
            case "question1":
                console.log('handleNext: Question 1');
                stage = "question2";
                //get previously seleted answers:
                let selectedAnswers = []
                for(let question of previousQuestions){
                    for(let answer of question.Answers__r){
                        if(answer.selected){
                            if(!$A.util.isUndefinedOrNull(answer.Product__c)){
                                selectedProducts.push(answer);
                                isProductSelected = true;
                            }
                            selectedAnswers.push(answer.Id);
                        }
                    }
                }
                //get question1 that has a process type of value
                for(let s of Object.keys(questionsAndAnswers.question2)){
                    let question = questionsAndAnswers.question2[s];
                    if(selectedAnswers.includes(question.Answer_1__c)){
                        for(let answer of question.Answer_2__r){
                            answer.selected = false;
                            if($A.util.isUndefinedOrNull(answer.Product__c) && $A.util.isUndefinedOrNull(answer.Products__c)){
                                answer.selectSingle = true;
                            } else {
                                answer.selectSingle = false;
                            }
                        }
                        questions.push(question);
                    }
                }
                break;
            case "question2":
                console.log('handleNext: Question 2');
                stage = "question3";
                //get previously seleted answers:
                let selectedAnswers2 = []
                for(let question of previousQuestions){
                    for(let answer of question.Answer_2__r){
                        if(answer.selected){
                            if(!$A.util.isUndefinedOrNull(answer.Product__c) || !$A.util.isUndefinedOrNull(answer.Products__c)){
                                selectedProducts.push(answer);
                                isProductSelected = true;
                            }
                            selectedAnswers2.push(answer.Id);
                        }
                    }
                }
                //get question1 that has a process type of value
                for(let s of Object.keys(questionsAndAnswers.question3)){
                    let question = questionsAndAnswers.question3[s];
                    if(selectedAnswers2.includes(question.Answer_2__c)){
                        if($A.util.isUndefinedOrNull(question.Answer_3__r)){
                            console.log('Answer 3 r is null');
                            question.Answer_3__r = [{
                                "Question_3__c" : question.Id,
                                "Question_3__r" : {
                                    "Id" : question.Id,
                                    "Name" : question.Name
                                },
                                "Name" : "Yes",
                                "Product__c" : question.Product__c,
                                "Products__c" : question.Products__c,
                                "Product__r" : {
                                    "Id" : question.Product__c,
                                    "Name" : question.Products__c
                                },
                                "selected" : false,
                                "Id" : question.Id,
                                "selectSingle" : false
                            }];
                        } else {
                            console.log('answer 3 r not undefined or null');
                            for(let answer of question.Answer_3__r){
                                answer.selected = false;
                                answer.selectSingle = false;
                            }
                        }
                        questions.push(question);
                    }
                }
                break;
            case "question3":
                console.log('handleNext: Question 3');
                stage = "review";
                //get previously seleted answers:
                let selectedAnswers3 = []
                for(let question of previousQuestions){
                    for(let answer of question.Answer_3__r){
                        if(answer.selected){
                            console.log(answer);
                            if(!$A.util.isUndefinedOrNull(answer.Product__c) || !$A.util.isUndefinedOrNull(answer.Products__c)){
                                selectedProducts.push(answer);
                                isProductSelected = true;
                            }
                            selectedAnswers3.push(answer.Id);
                        }
                    }
                }
                break;
        }
        if(isProductSelected){
            stage = 'review';
            component.set('v._selectedProducts', selectedProducts);
            component.set('v._isProductSelected', isProductSelected);
        } else {
            component.set('v._selectedProducts', []);
            component.set('v._isProductSelected', false);
        }
        component.set('v._isAnswerSelected', false);
        component.set('v._stage', stage);
        previousStates.push(questions);
        component.set('v._previousStates', previousStates);
        previousStages.push(stage);
        component.set('v._previousStages', previousStages);
        component.set('v._questions', questions);
    },
    
    handleCancel : function(component, event, helper){
        helper.closeWindow(component);
    },
    
    handleSubmit : function(component, event, helper){
        console.log('Submit!');
        component.set('v._isLoaded', false);
        helper.callSaveProductsToQuote(component, event, helper, false);
    },
    
    handleSubmitAndReset : function(component, event, helper){
        console.log('Submit!');
        component.set('v._isLoaded', false);
        helper.callSaveProductsToQuote(component, event, helper, true);
    }
})