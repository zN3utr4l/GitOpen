using GitOpen.Infrastructure.Persistence;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace GitOpen.Infrastructure.Tests.Helpers;

public static class InMemoryDb
{
    public static GitOpenDbContext CreateInMemory()
    {
        var conn = new SqliteConnection("Data Source=:memory:");
        conn.Open();
        var opts = new DbContextOptionsBuilder<GitOpenDbContext>()
            .UseSqlite(conn).Options;
        var ctx = new GitOpenDbContext(opts);
        ctx.Database.EnsureCreated();
        return ctx;
    }
}
