using System.Security.Cryptography;
using System.Text;
using Npgsql;

public sealed record DatabaseMigrationInfo(string Component, string Version, DateTimeOffset AppliedAt);

public static class DatabaseMigrationRunner
{
    public static string CanonicalSql(string sql) => sql.Replace("\r\n", "\n").Replace('\r', '\n');
    public static string Checksum(string sql) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(CanonicalSql(sql))));
    public static async Task ApplyAsync(
        NpgsqlConnection connection,
        string component,
        string version,
        string sql,
        CancellationToken cancellationToken)
    {
        if (connection.State != System.Data.ConnectionState.Open)
            throw new InvalidOperationException("Migration connection must be open.");

        var checksum = Checksum(sql);

        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await using (var lockCommand = new NpgsqlCommand(
            "select pg_advisory_xact_lock(hashtextextended('mazeduneh.schema-migrations', 0));",
            connection,
            transaction))
        {
            await lockCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        await using (var ledgerCommand = new NpgsqlCommand(
            """
            create table if not exists schema_migrations (
                component varchar(120) not null,
                version varchar(120) not null,
                checksum varchar(64) not null,
                applied_at timestamptz not null,
                primary key (component, version)
            );
            """,
            connection,
            transaction))
        {
            await ledgerCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        string? appliedChecksum;
        await using (var existingCommand = new NpgsqlCommand(
            """
            select checksum
            from schema_migrations
            where component = @component and version = @version;
            """,
            connection,
            transaction))
        {
            existingCommand.Parameters.AddWithValue("component", component);
            existingCommand.Parameters.AddWithValue("version", version);
            appliedChecksum = await existingCommand.ExecuteScalarAsync(cancellationToken) as string;
        }

        if (appliedChecksum is not null)
        {
            // Older builds hashed raw C# string line endings. Recognize only exact
            // LF/CRLF variants of this SQL, then upgrade the ledger to the portable hash.
            var legacyWindows = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(CanonicalSql(sql).Replace("\n", "\r\n"))));
            var legacyRaw = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(sql)));
            if (!string.Equals(appliedChecksum, checksum, StringComparison.Ordinal) && appliedChecksum != legacyWindows && appliedChecksum != legacyRaw)
                throw new InvalidOperationException(
                    $"Migration checksum mismatch for {component}/{version}. " +
                    "The applied migration must not be edited; create a new version instead.");

            if(appliedChecksum != checksum)
            {
                await using var normalize = new NpgsqlCommand("update schema_migrations set checksum=@checksum where component=@component and version=@version",connection,transaction);
                normalize.Parameters.AddWithValue("checksum",checksum);
                normalize.Parameters.AddWithValue("component",component);
                normalize.Parameters.AddWithValue("version",version);
                await normalize.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
            return;
        }

        await using (var migrationCommand = new NpgsqlCommand(sql, connection, transaction))
        {
            await migrationCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        await using (var recordCommand = new NpgsqlCommand(
            """
            insert into schema_migrations(component, version, checksum, applied_at)
            values (@component, @version, @checksum, now());
            """,
            connection,
            transaction))
        {
            recordCommand.Parameters.AddWithValue("component", component);
            recordCommand.Parameters.AddWithValue("version", version);
            recordCommand.Parameters.AddWithValue("checksum", checksum);
            await recordCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
    }

    public static async Task<IReadOnlyCollection<DatabaseMigrationInfo>> ListAsync(
        IConfiguration configuration,
        CancellationToken cancellationToken)
    {
        var connectionString = configuration.GetConnectionString("Catalog");
        if (string.IsNullOrWhiteSpace(connectionString))
            return Array.Empty<DatabaseMigrationInfo>();

        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        await using (var ledgerExists = new NpgsqlCommand(
            "select to_regclass('public.schema_migrations') is not null;", connection))
        {
            if (!Convert.ToBoolean(await ledgerExists.ExecuteScalarAsync(cancellationToken)))
                return Array.Empty<DatabaseMigrationInfo>();
        }
        await using var command = new NpgsqlCommand(
            """
            select component, version, applied_at
            from schema_migrations
            order by component, version;
            """,
            connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var migrations = new List<DatabaseMigrationInfo>();
        while (await reader.ReadAsync(cancellationToken))
        {
            migrations.Add(new DatabaseMigrationInfo(
                reader.GetString(0),
                reader.GetString(1),
                reader.GetFieldValue<DateTimeOffset>(2)));
        }
        return migrations;
    }
}
