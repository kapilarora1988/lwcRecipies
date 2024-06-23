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
        Test.startTest();
        System.enqueueJob(new AsyncReparentingChildRecords(a.Id, a1.Id));
        Test.stopTest();
        System.assertEquals(1, [Select Id from Account where Name like 'Kapil%'].size());
    }
}