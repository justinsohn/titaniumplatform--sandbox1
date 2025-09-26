global class EnhancedLoginEventCondition implements TxnSecurity.EventCondition{
    Private STATIC Integer range_minutes = 25; // minutes of login history to check if user logged in 60 minutes is max idk login history max time
    Private STATIC Integer logins_limit = 6; // users allowed login attempts within range_minutes
    
    
    public boolean evaluate(SObject event) {
        switch on event{
            when LoginEvent loginEvent {
                return evaluate2(loginEvent);
            }
            when null {
                return false;   
            }
            when else{
                return false;
            }
        }
    }
    
    public boolean evaluate2(LoginEvent loginEvent) {
        String nncrm_UserID = '00561000001izlMAAQ';
        Integer pardot_count = 0;
        system.debug('Time of event' + loginEvent.EventDate);
        dateTime start_time;
        
        start_time = subtract_minutes(loginEvent.EventDate, range_minutes); // subtracts minutes from the time of event to be used to see if user logged in more then 
        system.debug('Range to check' + start_time.format());      // 6 times in that time frame. 
        Integer logins =           [SELECT COUNT()
                                    FROM LoginHistory
                                    WHERE UserId = :loginEvent.UserId
                                    AND LoginTime >=: start_time];
        
        List<LoginHistory> login_types = [SELECT LoginType
                                          FROM LoginHistory
                                          WHERE UserId = :loginEvent.UserId
                                          AND LoginTime >=: start_time];  //2019-3-22T010:31:03Z
        
        List<LoginHistory> apps = [SELECT Application
                                          FROM LoginHistory
                                          WHERE UserId = :loginEvent.UserId
                                          AND LoginTime >=: start_time];  //2019-3-22T010:31:03Z
        // List<String> test = new List<String>();
        
        for(Integer x = 0; x < login_types.size(); x++)
        {
            //test.add(login_types.get(x).LoginType); 
            //if((login_types.get(x).LoginType).equals('Application'))
            //{
            //    pardot_count++;
            //}
            if(((apps.get(x).Application).equals('Pardot + Salesforce Connector')) || ((apps.get(x).Application).equals('Salesforce for Outlook')) || ((apps.get(x).Application).equals('SteelBrick CPQ'))){
                pardot_count++;
            }
        }
        
        //for(Integer x = 0; x < test.size(); x++)
        // {
        //   if(test.get(x).equals('Pardot + SalesForce Connector'))
        //   {
        //      pardot_count++;
        //   }    
        //}
        
        system.debug('size' + logins);
        
        if( (logins - pardot_count) >= logins_limit && ((loginEvent.UserId).equals(nncrm_UserID))) // exlucdes pardot from the nncrm user everyother user is not excluded 
        {
            system.debug('False');
            //send_emails(loginEvent, logins);        
            
            return false;
        }
        
         else if((logins - pardot_count) >= logins_limit)
        {
            system.debug('True');
            //send_emails(loginEvent, logins);        
            
            return true;
        }
        
        system.debug('False');
        return false;
        
        //AggregateResult[] results = [SELECT SourceIp
        //                             FROM LoginHistory
        //                             WHERE UserId = :loginEvent.UserId
        //                             AND LoginTime = LAST_N_DAYS:1
        //                             GROUP BY SourceIp];
        //if(!results.isEmpty()) {
        //    return true;
        //}
        //return false;
    }
    
    /*
    public void send_emails(LoginEvent loginEvent, Integer logins)
    {
        System.debug('You have made ' + Limits.getEmailInvocations() + ' email calls out of ' + Limits.getLimitEmailInvocations() + ' allowed');
        
        Messaging.reserveSingleEmailCapacity(1); // reserves email to ensure we don't exceed our daily email limit
        
        
        
        User usr = [Select Name From User where Id = :loginEvent.UserId ]; // gets the username from the userID for the email body 
        String userName = usr.Name; 
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage(); //inits the email object
        
        String[] toAddresses = new String[] {'Secalarms-sf@netnumber.com'}; 
            
            mail.setToAddresses(toAddresses);
        
        mail.setSenderDisplayName('Transaction Security');
        
        mail.setSubject('Login Limit Exceeded by ' + userName); // apex doesn't have format strings :^( well common sytax atleast haven't actually checked documentation 
        
        mail.setBccSender(false);
        
        mail.setUseSignature(true);
        
        dateTime event_time_in_est; // in est because that is the timezone of the nncrm user this will change as that users timezone changes
        
        event_time_in_est = subtract_minutes(loginEvent.EventDate, 0);
        
        mail.setPlainTextBody('The login limit was exceeded by ' + userName + '\n' + 'Logins: ' + logins + '\n' +'Time: ' + event_time_in_est );
        
        System.debug('You have made ' + Limits.getEmailInvocations() + ' email calls out of ' + Limits.getLimitEmailInvocations() + ' allowed');
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
        System.debug('You have made ' + Limits.getEmailInvocations() + ' email calls out of ' + Limits.getLimitEmailInvocations() + ' allowed');
        
    }

*/
    public dateTime subtract_minutes(dateTime start_time, Integer range_minutes) // subtracts minutes from the time passed
    {
        Integer new_minute;
        
        new_minute = start_time.minute() - range_minutes; // don't have to worry about a number being greater then 25 and causing negative minutes as datetime init handles negative minutes and sets the date to account for the negative minutes
        //e.g newInstance(2019, 1, 1, 0, -25, 3) returns the date 12/31/2018 11:35 PM // does not work for 24 in this data structure 24 != 0 it equals one full day ahead of the current 
        //That confused me so I made a note to help future people. 
        
        start_time = Datetime.newInstance(start_time.year(), start_time.month(), start_time.day(), start_time.hour(), new_minute, start_time.second());
        return start_time;
    }
}