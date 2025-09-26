//Author@ Jacob Ouellet
//For: NetNumber's shield security implementation
//Purpose: To trigger a warning if someone logs in more then 6 times in 25 minutes
//Date: 2/14/2019 Happy Valentines Day : )
//Version: 0.0.1
//Date: 3/21/2019 adding exclusion to pardot 
// Version 0.0.2

global class LoginPolicyCondition_revised implements TxnSecurity.PolicyCondition{
    Private STATIC Integer range_minutes = 25; // minutes of login history to check if user logged in 60 minutes is max idk login history max time
    Private STATIC Integer logins_limit = 6; // users allowed login attempts within range_minutes
    
  public boolean evaluate(TxnSecurity.Event e) {
      String nncrm_UserID = '00561000001izlMAAQ';
      Integer pardot_count = 0;
     system.debug('Time of event' + e.timeStamp);
    dateTime start_time; 
     
    start_time = subtract_minutes(e.timeStamp, range_minutes); // subtracts minutes from the time of event to be used to see if user logged in more then 
     system.debug('Range to check' + start_time.format());      // 6 times in that time frame. 
      Integer logins =           [SELECT COUNT()
                                 FROM LoginHistory
                                 WHERE UserId = :e.userId
                                 AND LoginTime >=: start_time];
      
      List<LoginHistory> login_types = [SELECT LoginType
                                 FROM LoginHistory
                                 WHERE UserId = :e.userId
                                 AND LoginTime >=: start_time];  //2019-3-22T010:31:03Z
   // List<String> test = new List<String>(); 
    
      for(Integer x = 0; x < login_types.size(); x++)
      {
          //test.add(login_types.get(x).LoginType);
          if((login_types.get(x).LoginType).equals('Application'))
          {
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
      
    if( (logins - pardot_count) >= logins_limit && e.userId.equals(nncrm_UserID)) // exlucdes pardot from the nncrm user everyother user is not excluded 
    {
      
        system.debug('True');
	 	send_emails(e, logins);        
     
        return true;
    }
    else if( logins >= logins_limit)
    {
        system.debug('True');
	 	send_emails(e, logins);        
     
        return true;
    }
     
      system.debug('False');
      return false;
  }
 
    private void send_emails(TxnSecurity.Event e, Integer logins)
    {
        System.debug('You have made ' + Limits.getEmailInvocations() + ' email calls out of ' + Limits.getLimitEmailInvocations() + ' allowed');
        
        Messaging.reserveSingleEmailCapacity(1); // reserves email to ensure we don't exceed our daily email limit
        
        
        
        User usr = [Select Name From User where Id = :e.userId ]; // gets the username from the userID for the email body 
			    String userName = usr.Name; 
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage(); //inits the email object

        String[] toAddresses = new String[] {'Secalarms-sf@netnumber.com'}; 
        
        mail.setToAddresses(toAddresses);
			
        mail.setSenderDisplayName('Transaction Security');
        
        mail.setSubject('Login Limit Exceeded by ' + userName); // apex doesn't have format strings :^( well common sytax atleast haven't actually checked documentation 
        
		mail.setBccSender(false);
		
        mail.setUseSignature(true);
        
        dateTime event_time_in_est; // in est because that is the timezone of the nncrm user this will change as that users timezone changes
        
        event_time_in_est = subtract_minutes(e.timeStamp, 0);
        
        mail.setPlainTextBody('The login limit was exceeded by ' + userName + '\n' + 'Logins: ' + logins + '\n' +'Time: ' + event_time_in_est );
        
        System.debug('You have made ' + Limits.getEmailInvocations() + ' email calls out of ' + Limits.getLimitEmailInvocations() + ' allowed');
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
        System.debug('You have made ' + Limits.getEmailInvocations() + ' email calls out of ' + Limits.getLimitEmailInvocations() + ' allowed');

    }
    private dateTime subtract_minutes(dateTime start_time, Integer range_minutes) // subtracts minutes from the time passed
    {
        Integer new_minute;
        
        new_minute = start_time.minute() - range_minutes; // don't have to worry about a number being greater then 25 and causing negative minutes as datetime init handles negative minutes and sets the date to account for the negative minutes
                                                          //e.g newInstance(2019, 1, 1, 0, -25, 3) returns the date 12/31/2018 11:35 PM // does not work for 24 in this data structure 24 != 0 it equals one full day ahead of the current 
                                                          //That confused me so I made a note to help future people. 
                                                          
        start_time = Datetime.newInstance(start_time.year(), start_time.month(), start_time.day(), start_time.hour(), new_minute, start_time.second());
        return start_time;
    }
}