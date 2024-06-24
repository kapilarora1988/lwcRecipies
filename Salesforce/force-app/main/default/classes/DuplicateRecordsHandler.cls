/**
*********************************************************
Apex Class Name    : DuplicateRecordsHandler
Created Date       : June 22, 2024
@description       : This is class is used for fetching duplicate records and merge the 
                     parent record to selected duplicate record
@author            : Kapil Arora
Modification Log:
Ver   Date         Author                               Modification
1.0   22-06-2024   Kapil Arora                      Initial Version
*********************************************************
*/
public with sharing class DuplicateRecordsHandler {
    
    /**
     * Custom Exception created for error handlicng
     */
    public class ConfigurationErrorException extends Exception {}


    /**
    *********************************************************
    @Method Name    : getDuplicateRecords
    @author         : Kapil Arora
    @description    : method  is used to fetch duplicates of a given record as per the configuration 
                      defined for duplicate criteria
    @param          : ID record,Integer limitSize, Integer offset
    @return         : Map<String, Object>
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDuplicateRecords(ID record,Integer limitSize, Integer offset){

        Map<String, Object> duplicateData = new Map<String, Object>();
        // Get the object type from record Id
        String objectType = record.getSObjectType().getDescribe().getName();
        boolean objectConfExists = false;
        boolean objectConfValid = false;
        String duplicateCriteriaFields = null;
        String fieldsToDisplay = null;

        // Fetch the configuration for given object if available
        for(Merge_Duplicate__mdt cmData : Merge_Duplicate__mdt.getAll().values()){
            if(cmData.Object_Name__c == objectType){
                objectConfExists = true;
                duplicateCriteriaFields = cmData.Duplicate_Criteria_Fields__c;
                fieldsToDisplay = cmData.Fields_To_Display__c;
                break;
            }
        }
        // If configuration for the given object is not available, throw custom exception
        if(!objectConfExists || String.isBlank(fieldsToDisplay) || String.isBlank(duplicateCriteriaFields)){
            throw new ConfigurationErrorException(Label.Merge_Duplicates_No_Conf);
        }else{
                Map<String, String> mapOfNameAndLabel = getObjectMetadata(objectType);
                // If any of the field mentioned in the configuration are not valid, it will not proceed
                if(!isValidConf(fieldsToDisplay,duplicateCriteriaFields,mapOfNameAndLabel)){
                    throw new ConfigurationErrorException(Label.Merge_Duplicates_Invalid_Conf);
                }else{
                    List<Map<String, String>> columns = new List<Map<String, String>>();
                    SObject masterRec = Database.query(getParentQuery(objectType,duplicateCriteriaFields,record));
                    duplicateData.put('data', Database.query(getDuplicateRecQuery(objectType,record,masterRec,fieldsToDisplay,duplicateCriteriaFields,
                    columns,mapOfNameAndLabel,limitSize,offset)));
                    duplicateData.put('columns',columns);
                }
        }

        return duplicateData;

    }


    /*********************************************************
    @Method Name    : getMergeRecordsData
    @author         : Kapil Arora
    @description    : This method  is used to fetch distinct record data for master and selected duplicate record
    @param          : String records - This will be concatenated ( with '--') value of master and selected duplicate record
    @return         : Map<String, Map<String,String>>
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static Map<String, Map<String,String>> getMergeRecordsData(String records){
        List<String> recordIds = records.split('--');
        String masterRec = recordIds[1];
        String recToBeMerged = recordIds[0];
        // Fetching the object type using record Id
        String objectType = ID.valueOf(masterRec).getSObjectType().getDescribe().getName();
        Map<String, String> mapOfNameAndLabel = getObjectMetadata(objectType);
        // Querying data for both parent and selected record to merge
        List<SObject> mergeRecordsData = Database.query(getMergeRecQuery(objectType,recordIds,mapOfNameAndLabel));
        List<SObject> sortedRecordsData = new List<SObject>();

        if(String.valueOf(mergeRecordsData[0].Id).equalsIgnoreCase(masterRec)){
            sortedRecordsData.add(mergeRecordsData[1]);
            sortedRecordsData.add(mergeRecordsData[0]);
        }else{
            sortedRecordsData.add(mergeRecordsData[0]);
            sortedRecordsData.add(mergeRecordsData[1]);
        }
        mergeRecordsData.clear();

        Map<String, Map<String,String>> mergeRecords = new Map<String,Map<String,String>>();
        for(SObject obj : sortedRecordsData){
            // Converting the SObject list to map for further execution logic
            Map<String,Object> objMap = obj.getPopulatedFieldsAsMap();
            for(String key : objMap.keySet()){
                if(!'Id'.equalsIgnoreCase(key)){
                    if(!mergeRecords.containsKey(key)){
                        Map<String,String> mergeRec = new Map<String,String>();
                        mergeRec.put('label',mapOfNameAndLabel.get(key));
                        mergeRec.put('fieldName',key);
                        mergeRec.put('val1', objMap.get(key) != null ? String.valueOf(objMap.get(key)) : '');
                        mergeRecords.put(key,mergeRec);
                    }else{
                        mergeRecords.get(key).put('val2', objMap.get(key) != null ? String.valueOf(objMap.get(key)) : '');
                    }
                }
            }
        }
        return mergeRecords;
    }
    

    /**********************************************************
    @Method Name    : doReparenting
    @author         : Kapil Arora
    @description    : This method  is used to call a future to do reparenting once merge operation is completed
    @param          : String records
    @return         : void
    ********************************************************
    */
    @AuraEnabled
    public static void doReparenting(String records){
        Id jobId = System.enqueueJob(new AsyncReparentingChildRecords(ID.valueOf(records.split('--')[1]), ID.valueOf(records.split('--')[0])));
        system.debug('Reparenting Queueable Job Id :'+jobId);
    }

    /**********************************************************
    @Method Name    : getObjectMetadata
    @author         : Kapil Arora
    @description    : This private method  is used to fetch record fields metadata
    @param          : String objectType - object name
    @return         : Map<String, String>
    ********************************************************
    */
    private static Map<String,String> getObjectMetadata(String objectName){
        Map<String,String> objectMetadata = new Map<String,String>();
        Map<String, Schema.SObjectType> detail = Schema.getGlobalDescribe();
        for(Schema.SObjectField field :detail.get(objectName).getDescribe().fields.getMap().Values()) {
            if(field.getDescribe().isAccessible() && field.getDescribe().isUpdateable()){
                objectMetadata.put(field.getDescribe().getName(), field.getDescribe().getLabel());
            }
        }
        return objectMetadata;
    }

    /**********************************************************
    @Method Name    : getParentQuery
    @author         : Kapil Arora
    @description    : This method  is used to create dynamic query for parent record details
    @param          : String objectType, String duplicateCriteriaFields,Id record
    @return         : String
    ********************************************************
    */
    private static String getParentQuery(String objectType, String duplicateCriteriaFields,Id record){
        String parentRecQuery = 'Select ';
        for(String field : duplicateCriteriaFields.split(',')){
            parentRecQuery += field.trim() + ',';
        }
        parentRecQuery = parentRecQuery.removeEnd(',');
        parentRecQuery += ' From '+objectType+' WHERE ID = :record';
        return parentRecQuery;
    }

    /**********************************************************
    @Method Name    : isValidConf
    @author         : Kapil Arora
    @description    : This method  is used to validate all the fields mentioned in the conf are valid
    @param          : String fieldsToDisplay,String duplicateCriteriaFields,Map<String, String> mapOfNameAndLabel
    @return         : boolean
    ********************************************************
    */
    private static boolean isValidConf(String fieldsToDisplay,String duplicateCriteriaFields,Map<String, String> mapOfNameAndLabel){
        boolean isValidConf = true;

        List<String> allFieldsToValidate = new List<String>();
        allFieldsToValidate.addAll(fieldsToDisplay.split(','));
        allFieldsToValidate.addAll(duplicateCriteriaFields.split(','));
        for(String field: allFieldsToValidate){
            if(!mapOfNameAndLabel.containsKey(field.trim())){
                isValidConf = false;
            }
        }
        return isValidConf;
    }
    /**********************************************************
    @Method Name    : getDuplicateRecQuery
    @author         : Kapil Arora
    @description    : This method  is used to create dynamic query for fetching duplicate records
    @param          : String objectType,String record,SObject masterRec,String fieldsToDisplay,String duplicateCriteriaFields,
                      List<Map<String, String>> columns,Map<String, String> mapOfNameAndLabel, Integer limitSize, Integer offset
    @return         : String
    ********************************************************
    */
    private static String getDuplicateRecQuery(String objectType,String record,SObject masterRec,String fieldsToDisplay,String duplicateCriteriaFields,
    List<Map<String, String>> columns,Map<String, String> mapOfNameAndLabel, Integer limitSize, Integer offset){
        String dupRecsQuery = 'Select ';
        if(!fieldsToDisplay.split(',').contains('Name')){
            dupRecsQuery += 'Name,';
        }
        for(String field : fieldsToDisplay.split(',')){
            if(!'Name'.equalsIgnoreCase(field)){
                // Populating map of columns to show in datatable dynamically
                Map<String, String> columnsVal = new Map<String, String>();
                columnsVal.put('label', mapOfNameAndLabel.get(field.trim()));
                columnsVal.put('fieldName', field.trim());
                columnsVal.put('type', 'text');
                columns.add(columnsVal);
            }
            dupRecsQuery += field.trim() + ',';
        }
        dupRecsQuery = dupRecsQuery.removeEnd(',') +' From '+objectType+' WHERE ID != :record AND ' ;
        
        for(String field : duplicateCriteriaFields.split(',')){
            dupRecsQuery += field.trim() +' = \''+ (String)masterRec.get(field.trim()) +'\''+' AND ';
        }
        // Limiting the data for lazy loading using OFFSET and LIMIT
        dupRecsQuery = dupRecsQuery.removeEnd(' AND ')+' LIMIT :limitSize OFFSET :offset';

        return dupRecsQuery;
    }

    /**********************************************************
    @Method Name    : getMergeRecQuery
    @author         : Kapil Arora
    @description    : This method  is used to create dynamic query for fetching record data of parent and selected record
    @param          : String objectType,String[] recordIds,Map<String, String> mapOfNameAndLabel
    @return         : String
    ********************************************************
    */
    private static String getMergeRecQuery(String objectType, String[] recordIds,Map<String, String> mapOfNameAndLabel ){
        String mergeRecQuery = 'Select ';
        mergeRecQuery += String.join(mapOfNameAndLabel.keySet(),',');
        mergeRecQuery += ' From '+objectType+' WHERE ID IN: recordIds order by Name';

        return mergeRecQuery;
    }
}