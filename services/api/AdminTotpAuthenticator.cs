using System.Buffers.Binary;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;

public sealed class AdminTotpAuthenticator
{
    private const int MinimumSecretBytes = 20;
    private const int Digits = 6;
    private const int TimeStepSeconds = 30;
    private const int AllowedClockSkewSteps = 1;
    private const int Modulus = 1_000_000;

    private readonly byte[] _secret;

    public AdminTotpAuthenticator(IConfiguration configuration)
    {
        _secret = TryDecodeSecret(configuration["Admin:Mfa:OwnerTotpSecret"], out var secret)
            ? secret
            : [];
    }

    public bool IsConfigured => _secret.Length >= MinimumSecretBytes;

    public bool TryMatchCode(string? code, DateTimeOffset now, out long matchedTimeStep)
    {
        matchedTimeStep = -1;
        if (!IsConfigured || !IsSixAsciiDigits(code)) return false;

        var currentTimeStep = now.ToUnixTimeSeconds() / TimeStepSeconds;
        var codeBytes = Encoding.ASCII.GetBytes(code!);
        var isMatch = false;

        for (var offset = -AllowedClockSkewSteps; offset <= AllowedClockSkewSteps; offset++)
        {
            var candidateTimeStep = currentTimeStep + offset;
            if (candidateTimeStep < 0) continue;

            var candidateBytes = Encoding.ASCII.GetBytes(CreateCode(_secret, candidateTimeStep));
            if (CryptographicOperations.FixedTimeEquals(codeBytes, candidateBytes))
            {
                matchedTimeStep = candidateTimeStep;
                isMatch = true;
            }
        }

        return isMatch;
    }

    private static string CreateCode(byte[] secret, long timeStep)
    {
        Span<byte> counter = stackalloc byte[sizeof(long)];
        BinaryPrimitives.WriteInt64BigEndian(counter, timeStep);
        var digest = HMACSHA1.HashData(secret, counter);
        var offset = digest[^1] & 0x0f;
        var binaryCode = BinaryPrimitives.ReadUInt32BigEndian(digest.AsSpan(offset, sizeof(uint))) & 0x7fffffff;
        return (binaryCode % Modulus).ToString($"D{Digits}", CultureInfo.InvariantCulture);
    }

    private static bool IsSixAsciiDigits(string? code)
    {
        if (code is not { Length: Digits }) return false;
        return code.All(character => character is >= '0' and <= '9');
    }

    private static bool TryDecodeSecret(string? encodedSecret, out byte[] secret)
    {
        secret = [];
        if (string.IsNullOrWhiteSpace(encodedSecret) || encodedSecret.Length > 128) return false;

        var normalized = encodedSecret.Trim().TrimEnd('=').ToUpperInvariant();
        var decoded = new List<byte>(normalized.Length * 5 / 8);
        var buffer = 0;
        var bufferedBits = 0;

        foreach (var character in normalized)
        {
            var value = DecodeBase32Character(character);
            if (value < 0) return false;

            buffer = (buffer << 5) | value;
            bufferedBits += 5;
            if (bufferedBits < 8) continue;

            bufferedBits -= 8;
            decoded.Add((byte)(buffer >> bufferedBits));
            buffer &= (1 << bufferedBits) - 1;
        }

        if (bufferedBits > 0 && buffer != 0) return false;
        if (decoded.Count < MinimumSecretBytes) return false;

        secret = decoded.ToArray();
        return true;
    }

    private static int DecodeBase32Character(char character) => character switch
    {
        >= 'A' and <= 'Z' => character - 'A',
        >= '2' and <= '7' => character - '2' + 26,
        _ => -1
    };
}
