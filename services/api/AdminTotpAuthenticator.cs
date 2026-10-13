using System.Buffers.Binary;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;

public static class AdminTotpAuthenticator
{
    private const string Base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    private const long TimeStepSeconds = 30;
    private const int CodeDigits = 6;
    private const int AllowedClockDriftSteps = 1;

    public static bool IsValidSecret(string? base32Secret) => TryDecodeSecret(base32Secret, out _);

    public static bool Verify(string? base32Secret, string? code, DateTimeOffset utcNow)
    {
        if (!TryDecodeSecret(base32Secret, out var secret) ||
            code is not { Length: CodeDigits } ||
            !code.All(char.IsAsciiDigit))
            return false;

        var currentStep = utcNow.ToUnixTimeSeconds() / TimeStepSeconds;
        var suppliedCode = Encoding.ASCII.GetBytes(code);
        for (var offset = -AllowedClockDriftSteps; offset <= AllowedClockDriftSteps; offset++)
        {
            var expectedCode = Encoding.ASCII.GetBytes(ComputeCode(secret, currentStep + offset));
            if (CryptographicOperations.FixedTimeEquals(suppliedCode, expectedCode))
                return true;
        }

        return false;
    }

    private static string ComputeCode(byte[] secret, long timeStep)
    {
        Span<byte> counter = stackalloc byte[sizeof(long)];
        BinaryPrimitives.WriteInt64BigEndian(counter, timeStep);
        var digest = HMACSHA1.HashData(secret, counter);
        var offset = digest[^1] & 0x0f;
        var binaryCode = ((digest[offset] & 0x7f) << 24) |
            ((digest[offset + 1] & 0xff) << 16) |
            ((digest[offset + 2] & 0xff) << 8) |
            (digest[offset + 3] & 0xff);
        return (binaryCode % 1_000_000).ToString("D6", CultureInfo.InvariantCulture);
    }

    private static bool TryDecodeSecret(string? value, out byte[] secret)
    {
        secret = [];
        if (string.IsNullOrWhiteSpace(value)) return false;

        var normalized = value.Trim().TrimEnd('=').Replace(" ", string.Empty, StringComparison.Ordinal).ToUpperInvariant();
        var output = new List<byte>(normalized.Length * 5 / 8);
        var buffer = 0;
        var bitsInBuffer = 0;
        foreach (var character in normalized)
        {
            var digit = Base32Alphabet.IndexOf(character);
            if (digit < 0) return false;

            buffer = (buffer << 5) | digit;
            bitsInBuffer += 5;
            if (bitsInBuffer < 8) continue;

            bitsInBuffer -= 8;
            output.Add((byte)((buffer >> bitsInBuffer) & 0xff));
        }

        if (output.Count < 16) return false;
        secret = output.ToArray();
        return true;
    }
}
