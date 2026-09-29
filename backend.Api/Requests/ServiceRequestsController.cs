using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;
using backend.Api.AI;

namespace TaskBridge.Api.Requests;

[ApiController]
[Route("api/requests")]
public class ServiceRequestsController : ControllerBase
{
    private readonly AuthDbContext _db;
    private readonly PlanningAgentService _planningService;
    private readonly ILogger<ServiceRequestsController> _logger;

    public ServiceRequestsController(
        AuthDbContext db,
        PlanningAgentService planningService,
        ILogger<ServiceRequestsController> logger)
    {
        _db = db;
        _planningService = planningService;
        _logger = logger;
    }

}