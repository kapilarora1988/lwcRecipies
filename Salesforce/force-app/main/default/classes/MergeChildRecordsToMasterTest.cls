@isTest
public class MergeChildRecordsToMasterTest {
    @isTest
    static void mergeChildRecordsTest() {
        Account a = new Account(Name = 'Kapil Arora1');
        INSERT a;
        Account a1 = new Account(Name = 'Kapil Arora2');
        INSERT a1;
        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = a1.Id);
        INSERT con;
        Task task = new Task(WhatId = a1.Id);
        INSERT task;
        Date dToday = Date.today();
        DateTime dt = DateTime.newInstance(dToday.year(), dToday.month(),dToday.day());
        Event event = new Event(WhatId = a1.Id, DurationInMinutes=15,ActivityDateTime=dt);
        INSERT event;
        Test.startTest();
        System.enqueueJob(new AsyncReparentingChildRecords(a.Id, a1.Id));
        Test.stopTest();
        System.assertEquals(1, [Select Id from Account where Name like 'Kapil%'].size());
        System.assertEquals(1, [Select Id from Contact where AccountId =  :a.Id].size());
        System.assertEquals(1, [Select Id from Task where WhatId =  :a.Id].size());
        System.assertEquals(1, [Select Id from Event where WhatId =  :a.Id].size());
    }
}