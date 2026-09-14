// L4D2 Friendly-Fire Stats - VScript 创意工坊模组
// 统计当前地图内幸存者之间的队友伤害；报告不会清零，只在换地图时重置。

::FFSTATS_TEAM_SURVIVOR <- 2;
::FFSTATS_REPORT_INTERVAL <- 60.0;
::FFStats_Damage <- {};
::FFStats_Hits <- {};
::FFStats_NextReportScheduled <- false;

::FFStats_Print <- function(text)
{
    ClientPrint(null, DirectorScript.HUD_PRINTTALK, text);
}

::FFStats_Reset <- function()
{
    ::FFStats_Damage = {};
    ::FFStats_Hits = {};
}

::FFStats_IsSurvivor <- function(entity)
{
    if (entity == null)
    {
        return false;
    }
    return NetProps.GetPropInt(entity, "m_iTeamNum") == FFSTATS_TEAM_SURVIVOR;
}

::FFStats_GetPlayerName <- function(entity)
{
    if (entity == null)
    {
        return "未知玩家";
    }

    local name = entity.GetPlayerName();
    if (name == null || name == "")
    {
        name = entity.GetName();
    }
    return name;
}

::FFStats_SumHits <- function()
{
    local total = 0;
    foreach (hits in FFStats_Hits)
    {
        total += hits;
    }
    return total;
}

::FFStats_Report <- function()
{
    local survivors = [];
    local totalDamage = 0;

    local player = null;
    while ((player = Entities.FindByClassname(player, "player")) != null)
    {
        if (NetProps.GetPropInt(player, "m_iTeamNum") != FFSTATS_TEAM_SURVIVOR)
        {
            continue;
        }

        // 关键修复：改为实体方法调用 player.GetPlayerUserId()
        local userId = player.GetPlayerUserId();
        if (userId == -1)
        {
            continue;
        }

        local damage = FFStats_Damage.rawin(userId) ? FFStats_Damage[userId] : 0;
        local hits = FFStats_Hits.rawin(userId) ? FFStats_Hits[userId] : 0;
        totalDamage += damage;
        survivors.append({ entity = player, userId = userId, damage = damage, hits = hits });
    }

    if (survivors.len() == 0)
    {
        return;
    }

    FFStats_Print("[黑枪统计] 本地图累计队友伤害：" + totalDamage + " 点，共 " + FFStats_SumHits() + " 次。");

    local hasDamage = false;
    foreach (entry in survivors)
    {
        if (entry.hits > 0)
        {
            hasDamage = true;
            break;
        }
    }

    if (!hasDamage)
    {
        FFStats_Print("[黑枪统计] 本地图尚未检测到队友伤害。");
    }
    else
    {
        foreach (entry in survivors)
        {
            FFStats_Print("  " + FFStats_GetPlayerName(entry.entity) + "：" + entry.damage + " 点伤害，" + entry.hits + " 次");
        }
    }
}

::FFStats_ScheduleNextReport <- function()
{
    EntFire("worldspawn", "RunScriptCode", "::FFStats_ReportAndReschedule()", FFSTATS_REPORT_INTERVAL);
}

::FFStats_ReportAndReschedule <- function()
{
    FFStats_Report();
    FFStats_ScheduleNextReport();
}

::FFStats_Scope <-
{
    function OnGameEvent_player_hurt(params)
    {
        if (!params.rawin("userid") || !params.rawin("attacker"))
        {
            return;
        }

        local victim = GetPlayerFromUserID(params.userid);
        local attacker = GetPlayerFromUserID(params.attacker);
        if (victim == null || attacker == null || victim == attacker)
        {
            return;
        }
        
        if (!::FFStats_IsSurvivor(victim) || !::FFStats_IsSurvivor(attacker))
        {
            return;
        }

        local damage = 0;
        if (params.rawin("dmg_health"))
        {
            damage = params.dmg_health;
        }
        if (damage <= 0 && params.rawin("damageamount"))
        {
            damage = params.damageamount;
        }
        if (damage <= 0)
        {
            return;
        }

        local attackerId = params.attacker;
        if (!FFStats_Damage.rawin(attackerId))
        {
            FFStats_Damage[attackerId] <- 0;
            FFStats_Hits[attackerId] <- 0;
        }
        FFStats_Damage[attackerId] += damage;
        FFStats_Hits[attackerId] += 1;
    }
};

FFStats_Reset();
__CollectGameEventCallbacks(FFStats_Scope);
if (!FFStats_NextReportScheduled)
{
    FFStats_NextReportScheduled = true;
    FFStats_ScheduleNextReport();
}