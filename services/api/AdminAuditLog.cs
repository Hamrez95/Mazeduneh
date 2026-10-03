using System.Text.Json;
using Npgsql;
using NpgsqlTypes;

public sealed class AdminAuditLogDatabase(IConfiguration configuration, ILogger<AdminAuditLogDatabase> logger)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        const string sql = """
            create table if not exists admin_audit_logs (
                id uuid primary key,
                actor text not null,
                action varchar(120) not null,
                entity_type varchar(80) not null,
                entity_id varchar(120) not null,
                before_json jsonb null,
                after_json jsonb null,
                reason text not null,
                request_id varchar(120) not null,
                occurred_at timestamptz not null
            );
            create index if not exists ix_admin_audit_logs_entity on admin_audit_logs(entity_type, entity_id, occurred_at desc);
            create index if not exists ix_admin_audit_logs_occurred on admin_audit_logs(occurred_at desc);
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "admin-audit", "001-bootstrap", sql, cancellationToken);
        logger.LogInformation("Admin audit log schema is ready.");
    }

    public Task RecordAsync(
        string actor,
        string action,
        string entityType,
        string entityId,
        object? before,
        object? after,
        string reason,
        string requestId,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Task.CompletedTask;
        return RecordWithConnectionAsync(null, null, actor, action, entityType, entityId, before, after, reason, requestId, cancellationToken);
    }

    public Task RecordAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string actor,
        string action,
        string entityType,
        string entityId,
        object? before,
        object? after,
        string reason,
        string requestId,
        CancellationToken cancellationToken) =>
        RecordWithConnectionAsync(connection, transaction, actor, action, entityType, entityId, before, after, reason, requestId, cancellationToken);

    public async Task<IReadOnlyCollection<AdminAuditLogEntry>> ListAsync(string? entityType, string? entityId, int limit, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<AdminAuditLogEntry>();
        const string sql = """
            select id,actor,action,entity_type,entity_id,before_json,after_json,reason,request_id,occurred_at
            from admin_audit_logs
            where (@entity_type = '' or entity_type = @entity_type)
              and (@entity_id = '' or entity_id = @entity_id)
            order by occurred_at desc
            limit @limit;
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("entity_type", entityType?.Trim() ?? string.Empty);
        command.Parameters.AddWithValue("entity_id", entityId?.Trim() ?? string.Empty);
        command.Parameters.AddWithValue("limit", limit);
        var result = new List<AdminAuditLogEntry>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            result.Add(new AdminAuditLogEntry(
                reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4),
                reader.IsDBNull(5) ? null : reader.GetString(5), reader.IsDBNull(6) ? null : reader.GetString(6),
                reader.GetString(7), reader.GetString(8), reader.GetFieldValue<DateTimeOffset>(9)));
        return result;
    }

    private async Task RecordWithConnectionAsync(
        NpgsqlConnection? connection,
        NpgsqlTransaction? transaction,
        string actor,
        string action,
        string entityType,
        string entityId,
        object? before,
        object? after,
        string reason,
        string requestId,
        CancellationToken cancellationToken)
    {
        var ownsConnection = connection is null;
        connection ??= new NpgsqlConnection(_connectionString);
        await using var owned = ownsConnection ? connection : null;
        if (ownsConnection) await connection.OpenAsync(cancellationToken);
        const string sql = """
            insert into admin_audit_logs
                (id,actor,action,entity_type,entity_id,before_json,after_json,reason,request_id,occurred_at)
            values
                (@id,@actor,@action,@entity_type,@entity_id,@before_json,@after_json,@reason,@request_id,@occurred_at);
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("id", Guid.NewGuid());
        command.Parameters.AddWithValue("actor", actor.Trim());
        command.Parameters.AddWithValue("action", action.Trim());
        command.Parameters.AddWithValue("entity_type", entityType.Trim());
        command.Parameters.AddWithValue("entity_id", entityId.Trim());
        command.Parameters.Add(new NpgsqlParameter("before_json", NpgsqlDbType.Jsonb) { Value = before is null ? DBNull.Value : JsonSerializer.Serialize(before) });
        command.Parameters.Add(new NpgsqlParameter("after_json", NpgsqlDbType.Jsonb) { Value = after is null ? DBNull.Value : JsonSerializer.Serialize(after) });
        command.Parameters.AddWithValue("reason", reason.Trim());
        command.Parameters.AddWithValue("request_id", requestId.Trim());
        command.Parameters.AddWithValue("occurred_at", DateTimeOffset.UtcNow);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}

public sealed class AdminAuditLogSchemaInitializer(AdminAuditLogDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken) => database.InitializeAsync(cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

public sealed record AdminAuditLogEntry(Guid Id, string Actor, string Action, string EntityType, string EntityId,
    string? BeforeJson, string? AfterJson, string Reason, string RequestId, DateTimeOffset OccurredAt);
