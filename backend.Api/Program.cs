using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Data;

var builder = WebApplication.CreateBuilder(args);