@isTest
public class DuplicateRecordsHandlerTest {
    @isTest
    static void getDuplicatesAndMergeRecordsTest() {
        Account a = new Account(Name = 'Kapil Arora1');
        INSERT a;
        Account a1 = new Account(Name = 'Kapil Arora2');
        INSERT a1;
        System.assertEquals(2,DuplicateRecordsHandler.getDuplicateRecords(a.Id, 2, 2).size());
        System.assertEquals(true, DuplicateRecordsHandler.getMergeRecordsData(a.Id + '--' + a1.Id).containsKey('Name'));
    }
}