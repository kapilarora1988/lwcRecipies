public with sharing class AsyncReparentingChildRecords implements Queueable {
    private Id masterId, slaveId;
    public AsyncReparentingChildRecords(Id masterIdParam, Id slaveIdParam) {
        masterId = masterIdParam;
        slaveId = slaveIdParam;
    }
    public void execute(QueueableContext context) {
        MergeChildRecordsToMaster.mergeChildRecords(masterId,slaveId);      
    }
}