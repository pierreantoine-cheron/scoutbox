using System.IO;
using System.Text;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using ScoutBoxApi.Data;
using ScoutBoxApi.Filters;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers(options =>
{
    options.Filters.Add<ApiExceptionFilter>();
});

// Add OpenAPI/Swagger
builder.Services.AddOpenApi();
builder.Services.AddSwaggerGen();

// Add application services
builder.Services.AddSingleton<TokenService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUserAccessor, CurrentUserAccessor>();
builder.Services.AddScoped<IAuditService, AuditService>();
builder.Services.AddScoped<IAuditHistoryService, AuditHistoryService>();
builder.Services.AddScoped<TentService>();

var dataProtectionKeysRoot = builder.Configuration["Storage:DataProtectionKeysRoot"]
    ?? Path.Combine(AppContext.BaseDirectory, "data-protection-keys");

Directory.CreateDirectory(dataProtectionKeysRoot);

builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(dataProtectionKeysRoot))
    .SetApplicationName("ScoutBoxApi");

// Configure SQLite with WAL mode
builder.Services.AddDbContext<ScoutBoxDbContext>(options =>
{
    options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection"), sqliteOptions =>
    {
        sqliteOptions.MigrationsAssembly("ScoutBoxApi");
    });
});

// Configure JWT Authentication
var jwtSettings = TokenService.GetValidatedJwtSettings(builder.Configuration);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtSettings.Issuer,
            ValidAudience = jwtSettings.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings.Key)),
            ClockSkew = TimeSpan.Zero
        };

        // Configure custom challenge/forbidden responses with error codes
        options.Events = new JwtBearerEvents
        {
            OnChallenge = async context =>
            {
                context.HandleResponse();
                context.Response.StatusCode = 401;
                context.Response.ContentType = "application/json";
                var errorResponse = new ErrorResponse("Invalid or expired token", "AUTH_INVALID_TOKEN");
                await context.Response.WriteAsJsonAsync(errorResponse);
            },
            OnForbidden = async context =>
            {
                context.Response.StatusCode = 403;
                context.Response.ContentType = "application/json";
                var errorResponse = new ErrorResponse("Access denied", "FORBIDDEN");
                await context.Response.WriteAsJsonAsync(errorResponse);
            }
        };
    });

builder.Services.AddAuthorization();

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;

    // PaaS can terminate TLS at the proxy layer, so the API must trust
    // forwarded headers to avoid incorrect redirect and scheme behavior.
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

// Configure Rate Limiting
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("auth", opt =>
    {
        opt.PermitLimit = 10;
        opt.Window = TimeSpan.FromMinutes(1);
        opt.QueueProcessingOrder = System.Threading.RateLimiting.QueueProcessingOrder.OldestFirst;
        opt.QueueLimit = 2;
    });

    options.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.StatusCode = 429;
        await context.HttpContext.Response.WriteAsync("Too many requests. Please try again later.", token);
    };
});

var app = builder.Build();

// Apply migrations and ensure database is created
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
    dbContext.Database.Migrate();

    // Enable WAL mode for SQLite
    dbContext.Database.ExecuteSqlRaw("PRAGMA journal_mode=WAL;");

    // Note: Data seeding is handled by UseSeeding/UseAsyncSeeding in ScoutBoxDbContext.OnConfiguring()
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseForwardedHeaders();

app.UseHttpsRedirection();

app.UseRateLimiter();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();

// Declaration used by WebApplicationFactory
public partial class Program
{
}
