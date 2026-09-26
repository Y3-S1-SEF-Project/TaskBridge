using System.Security.Cryptography;
using System.Text;

namespace TaskBridge.Api.Auth;

/// <summary>
/// AES-256 Symmetric Encryption Service for securing chat messages and attachments at rest.
/// Complies with enterprise security governance while allowing authorized audit access.
/// </summary>
public sealed class ChatCrypto
{
    private readonly byte[] _key;

    public ChatCrypto(IConfiguration config)
    {
        // 256-bit (32 bytes) master key from appsettings or fallback deterministic derivation
        var rawKey = config["Chat:EncryptionKey"] ?? "TaskBridge_AES256_SecretKey_9874523412345678";
        using var sha = SHA256.Create();
        _key = sha.ComputeHash(Encoding.UTF8.GetBytes(rawKey));
    }

    /// <summary>
    /// Encrypts plaintext string using AES-256-CBC with a unique initialization vector (IV).
    /// Returns Base64 payload containing IV + Ciphertext.
    /// </summary>
    public string Encrypt(string plainText)
    {
        if (string.IsNullOrEmpty(plainText)) return string.Empty;

        using var aes = Aes.Create();
        aes.Key = _key;
        aes.GenerateIV();

        using var encryptor = aes.CreateEncryptor(aes.Key, aes.IV);
        using var ms = new MemoryStream();
        
        // Prepend 16-byte IV to the stream
        ms.Write(aes.IV, 0, aes.IV.Length);

        using (var cs = new CryptoStream(ms, encryptor, CryptoStreamMode.Write))
        using (var writer = new StreamWriter(cs, Encoding.UTF8))
        {
            writer.Write(plainText);
        }

        return Convert.ToBase64String(ms.ToArray());
    }

    /// <summary>
    /// Decrypts Base64 payload containing IV + Ciphertext.
    /// Safely handles unencrypted fallback strings for backwards compatibility.
    /// </summary>
    public string Decrypt(string cipherPayload)
    {
        if (string.IsNullOrEmpty(cipherPayload)) return string.Empty;

        try
        {
            var fullBytes = Convert.FromBase64String(cipherPayload);
            if (fullBytes.Length < 16) return cipherPayload; // Not an encrypted payload

            using var aes = Aes.Create();
            aes.Key = _key;

            var iv = new byte[16];
            Array.Copy(fullBytes, 0, iv, 0, 16);
            aes.IV = iv;

            using var decryptor = aes.CreateDecryptor(aes.Key, aes.IV);
            using var ms = new MemoryStream(fullBytes, 16, fullBytes.Length - 16);
            using var cs = new CryptoStream(ms, decryptor, CryptoStreamMode.Read);
            using var reader = new StreamReader(cs, Encoding.UTF8);

            return reader.ReadToEnd();
        }
        catch
        {
            // If decryption fails (e.g., legacy plain text), return input safely
            return cipherPayload;
        }
    }
}
