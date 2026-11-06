public with sharing class AIResponseParser {
    
    public class InputWrapper {
        @InvocableVariable(required=true)
        public String jsonString;
    }

    public class OutputWrapper {
        @InvocableVariable public String program;
        @InvocableVariable public String agreementName;
        @InvocableVariable public Decimal amount;
        @InvocableVariable public Date startDate;
        @InvocableVariable public Date endDate;
        @InvocableVariable public String purpose;
    }

    @InvocableMethod(label='Parse AI Response' description='Parses AI JSON response into fields')
    public static List<OutputWrapper> parse(List<InputWrapper> inputs){
        
        List<OutputWrapper> results = new List<OutputWrapper>();
        
        for(InputWrapper inp : inputs){
            
            OutputWrapper out = new OutputWrapper();
            
            System.debug('==== START ====');

            if(String.isNotBlank(inp.jsonString)){
                
                try{
                    String cleanJson = inp.jsonString;

                    System.debug('RAW INPUT: ' + cleanJson);

                    // 🔥 STEP 1: Remove invalid unicode chars (VERY IMPORTANT)
                    cleanJson = cleanJson.replaceAll('[^\\x20-\\x7E]', '');

                    // 🔥 STEP 2: Extract JSON only
                    Integer startIndex = cleanJson.indexOf('{');
                    Integer endIndex = cleanJson.lastIndexOf('}');

                    if(startIndex != -1 && endIndex != -1 && endIndex > startIndex){
                        cleanJson = cleanJson.substring(startIndex, endIndex + 1);
                    }

                    cleanJson = cleanJson.trim();

                    System.debug('CLEAN JSON: ' + cleanJson);

                    // 🔥 STEP 3: Parse
                    Map<String, Object> data = 
                        (Map<String, Object>) JSON.deserializeUntyped(cleanJson);

                    System.debug('MAP: ' + data);

                    // PROGRAM
                    out.program = (String)data.get('program');
                    System.debug('PROGRAM: ' + out.program);

                    // AGREEMENT NAME
                    out.agreementName = (String)data.get('agreementName');
                    System.debug('AGREEMENT NAME: ' + out.agreementName);

                    // AMOUNT
                    if(data.get('amount') != null){
                        out.amount = Decimal.valueOf(String.valueOf(data.get('amount')));
                    }
                    System.debug('AMOUNT: ' + out.amount);

                    // START DATE
                    if(data.get('startDate') != null){
                        out.startDate = Date.valueOf((String)data.get('startDate'));
                    }
                    System.debug('START DATE: ' + out.startDate);

                    // END DATE
                    if(data.get('endDate') != null){
                        out.endDate = Date.valueOf((String)data.get('endDate'));
                    }
                    System.debug('END DATE: ' + out.endDate);

                    // PURPOSE
                    out.purpose = (String)data.get('purpose');
                    System.debug('PURPOSE: ' + out.purpose);

                } catch(Exception e){
                    System.debug('❌ ERROR: ' + e.getMessage());
                }
            }

            System.debug('FINAL OUT: ' + out);
            System.debug('==== END ====');

            results.add(out);
        }
        
        return results;
    }
}