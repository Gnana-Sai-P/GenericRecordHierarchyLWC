/**
 * @description Apex controller class designed to handle record hierarchies for 
 * specified records and customized metadata settings. The class enables fetching and organizing 
 * hierarchical data, utilising dynamic SOQL queries dependent on provided input parameters.
 * This class is optimized for use with Aura and Lightning Web Components.
 *
 * @author Gnanasai Pedagopu
 * @date 2024-10-10
 * @version 1.0
 */

 public with sharing class HierarchyController {
    // Name of the custom metadata used for configuring this controller
    public static String customMedataName = 'Data_table_Tree_Grid_Configuration__mdt';
    
    /**
     * Aggregates different hierarchical data retrieval functions to compile a complete hierarchy view 
     * centered around a specific record.
     *
     * @param queryParams Object containing parameters necessary for queries
     * @return HierarchyWrapper which includes the constructed hierarchy
     */
    @AuraEnabled(cacheable=true)
    public static HierarchyWrapper getAllRecordHierarchy(QueryWrapper queryParams){
        List<sObject> currentRecord = getCurrentRecord(queryParams); // Retrieves the starting (root) record based on query parameters
        List<sObject> hierarchyRecords = getHierarchyRecords(queryParams, currentRecord); // Fetches the complete set of records involved in the hierarchy
        return getAllHierarchy(hierarchyRecords, queryParams.parentFieldApiName); // Construct hierarchy structure
    }
    
    /**
     * Organizes given list of sObjects into a hierarchy structure based on a parent field API name.
     *
     * @param recordList List of sObject which represents the queried records that will be structured into hierarchy
     * @param parentFieldApiName The API name of the field used to identify parent-child relationships
     * @return HierarchyWrapper with structured data detailing parents, children, and the overall count
     */
    @AuraEnabled
    public static HierarchyWrapper getAllHierarchy(List<sObject> recordList, String parentFieldApiName){
        Map<String, List<sObject>> mapOfParentsWithListOfChild = new Map<String, List<sObject>>();
        List<sObject> parentList = new List<sObject>();

        for(sObject record : recordList) {
            if(record.get(parentFieldApiName) != null){
                String parentKey = (String)record.get(parentFieldApiName);
                if(mapOfParentsWithListOfChild.containsKey(parentKey)){
                    mapOfParentsWithListOfChild.get(parentKey).add(record);
                }else{
                    mapOfParentsWithListOfChild.put(parentKey, new List<sObject>{record});
                }
            } else {
                parentList.add(record); // This record does not have a parent and is treated as a top-level item
            }
        }

        HierarchyWrapper wrapper = new HierarchyWrapper();
        wrapper.superParentList = parentList;
        wrapper.parentMap = mapOfParentsWithListOfChild;
        wrapper.totalRecordCount = recordList.size();
        wrapper.baseUrl = getBaseUrl();
        return wrapper; // Constructed hierarchy data
    }
    
    /**
     * Executes a SOQL query to fetch the rendered current record based upon the input parameters contained in a QueryWrapper.
     *
     * @param qp QueryWrapper containing query parameters
     * @return List of sObject representing the fetched current record(s), empty if none found.
     */
    public static List<sObject> getCurrentRecord(QueryWrapper qp){
        string selectClause = 'SELECT ' + qp.rootFieldApiName;
        string fromClause = ' FROM ' + qp.sObjectApiName;
        string whereClause = ' WHERE Id = \'' + qp.recordId + '\'';
        system.debug('selectClause='+selectClause);
        system.debug('fromClause='+fromClause);
        system.debug('whereClause='+whereClause);
        return performQuery(selectClause, fromClause, whereClause); // Dynamic query execution to fetch current record
    }
    
    /**
     * Fetches records related to the current record to help build the hierarchy
     *
     * @param qp QueryWrapper containing necessary fields and parameters
     * @param currentRecord List of sObject representing current base records
     * @return List of sObject representing the hierarchy records, empty if none found.
     */
    public static List<sObject> getHierarchyRecords(QueryWrapper qp, List<sObject> currentRecord){
        qp.fieldsToQuery += ',' + qp.parentFieldApiName;
        String selectClause = 'SELECT ' + qp.fieldsToQuery;
        String fromClause = ' FROM ' + qp.sObjectApiName;
        String rootRecordId = !currentRecord.isEmpty() ? (String)currentRecord[0].get(qp.rootFieldApiName) : '';
        String whereClause = ' WHERE ' + qp.rootFieldApiName + ' = \'' + rootRecordId + '\'';
        system.debug('selectClause='+selectClause);
        system.debug('fromClause='+fromClause);
        system.debug('whereClause='+whereClause);
        return performQuery(selectClause, fromClause, whereClause); // Query to fetch hierarchical records
    }
    
    /**
     * Retrieves custom metadata configuration for specified template.
     *
     * @param templateName The name of the template to query metadata
     * @return sObject representing the first (or only) record matching the criteria, null if none found.
     */
    @AuraEnabled(cacheable=true)
    public static sObject getCustomMetadata(String templateName){
        List<sObject> mdtaRecords;
        List<String> customMetadataFields = getsObjectFieldApiNames(customMedataName);
        String selectClause = 'SELECT ' + String.join(customMetadataFields, ',');
        String fromClause = ' FROM ' + customMedataName;
        String whereClause = ' WHERE MasterLabel = \'' + templateName + '\'';

        mdtaRecords = performQuery(selectClause, fromClause, whereClause); // Query to fetch Custom metadata records
        return mdtaRecords <> NULL && !mdtaRecords.isEmpty() ? mdtaRecords[0] : NULL;
    }
    
    /**
     * Utility method to dynamically fetch field API names for a specified sObject or custom metadata type.
     *
     * @param objectApiName API name of the sObject from which to retrieve field names
     * @return List of String representing field API names.
     */
    public static List<String> getsObjectFieldApiNames(String objectApiName) {
        List<String> fieldApiNames = new List<String>();
        SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
        
        if (sObjType != null) {
            Map<String, Schema.SObjectField> mFields = sObjType.getDescribe().fields.getMap();
            for (String fieldName : mFields.keySet()) {
                fieldApiNames.add(fieldName); 
            }
        }
        
        return fieldApiNames;
    }
    
    /**
     * Executes a constructed query string and returns a list of sObject results.
     *
     * @param selectClause SELECT segment of the SOQL query
     * @param fromClause FROM segment of the SOQL query
     * @param whereClause WHERE segment of the SOQL query
     * @return List of sObject representing the results of the query.
     */
    public static List<sObject> performQuery(string selectClause, string fromClause, string whereClause) {
        String queryString = selectClause + fromClause + whereClause;
        return Database.query(queryString);
    }
     
    /**
     * Utility method to dynamically fetch base URL for the org.
     *
     * @return String representing the base URL for the Org.
     */
    public static String getBaseUrl() {
        return URL.getOrgDomainURL().toExternalForm();
    }
    
    // Inner class to hold and structure hierarchical data
    public class HierarchyWrapper {
        @AuraEnabled public List<sObject> superParentList {get;set;}
        @AuraEnabled public Map<String,List<sObject>> parentMap {get;set;}
        @AuraEnabled public Integer totalRecordCount {get;set;}
        @AuraEnabled public String baseUrl {get;set;}
    }
    
    // Inner class used for packaging query parameters
    public class QueryWrapper {
        @AuraEnabled public String sObjectApiName {get;set;}
        @AuraEnabled public String recordId {get;set;}
        @AuraEnabled public String rootFieldApiName {get;set;}
        @AuraEnabled public String parentFieldApiName {get;set;}
        @AuraEnabled public String fieldsToQuery {get;set;}
    }
}