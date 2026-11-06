public class EncryptionUtil {
    @InvocableMethod(label='Encrypt Value')
    public static List<String> encrypt(List<String> inputs) {
        List<String> results = new List<String>();
        Blob key = Crypto.generateAesKey(128);

        for (String val : inputs) {
            Blob data = Blob.valueOf(val);
            Blob encrypted = Crypto.encryptWithManagedIV('AES128', key, data);
            results.add(EncodingUtil.base64Encode(encrypted));
        }
        return results;
    }
}