
#if SERVER
global function Rampage_Core_UseMeter
#endif

global function OnCoreCharge_Rampage_Core
global function OnCoreChargeEnd_Rampage_Core
global function OnAbilityStart_Rampage_Core





bool function OnCoreCharge_Rampage_Core( entity weapon )
{
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

#if SERVER
	entity owner = weapon.GetWeaponOwner()
#endif

	return true
}

void function OnCoreChargeEnd_Rampage_Core( entity weapon )
{
	#if SERVER
	entity owner = weapon.GetWeaponOwner()

	OnAbilityChargeEnd_TitanCore( weapon )
	#endif
}



var function OnAbilityStart_Rampage_Core( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnAbilityStart_TitanCore( weapon )

	entity owner = weapon.GetWeaponOwner()

	if ( !owner.IsTitan() )
		return 0

	if ( !IsValid( owner ) )
		return


#if SERVER


	entity soul = owner.GetTitanSoul()

	float delay = weapon.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
	thread Rampage_Core_End( weapon, owner, delay )
#endif
	entity player = weapon.GetWeaponOwner()
	player.AddSharedEnergy(player.GetSharedEnergyTotal() - player.GetSharedEnergyCount())

	array<string> Mods = owner.GetMainWeapons()[0].GetMods()
    array<string> HeatMods = ["HeatLevel4", "HeatLevel3", "HeatLevel2", "HeatLevel1", "HeatLevel5"]

    foreach(string mod in HeatMods)
    {
        Mods.fastremovebyvalue(mod)
    }
	Mods.append("RampageCore")
	
	owner.GetMainWeapons()[0].SetMods(Mods)
	
	foreach(entity weapon in owner.GetOffhandWeapons())
	{
		if(weapon.GetWeaponClassName() == "exrill_mp_titanweapon_rod_from_god")
			weapon.AddMod("RampageCore")
	}

	return 1
}

#if SERVER
void function Rampage_Core_End( entity weapon, entity player, float delay )
{
	weapon.EndSignal( "OnDestroy" )

	if ( player.IsNPC() && !IsAlive( player ) )
		return

	player.EndSignal( "OnDestroy" )
	if ( IsAlive( player ) )
		player.EndSignal( "OnDeath" )
	player.EndSignal( "TitanEjectionStarted" )
	player.EndSignal( "DisembarkingTitan" )
	player.EndSignal( "OnSyncedMelee" )
	player.EndSignal( "InventoryChanged" )

	OnThreadEnd(
	function() : ( weapon, player )
		{
			OnAbilityEnd_Rampage_Core( weapon, player )

			if ( IsValid( player ) )
			{
				entity soul = player.GetTitanSoul()
				if ( soul != null )
					CleanupCoreEffect( soul )
			}
		}
	)

	entity soul = player.GetTitanSoul()
	if ( soul == null )
		return

	while ( 1 )
	{
		if ( soul.GetCoreChargeExpireTime() <= Time() )
			break;
		wait 0.1
	}
}

void function OnAbilityEnd_Rampage_Core( entity weapon, entity player )
{
	OnAbilityEnd_TitanCore( weapon )

	if ( player.IsPlayer() )
	{
		player.SetPowerRegenRateScale( 1.0 )
		EmitSoundOnEntityOnlyToPlayer( player, player, "Titan_Ronin_Sword_Core_Deactivated_1P" )
		EmitSoundOnEntityExceptToPlayer( player, player, "Titan_Ronin_Sword_Core_Deactivated_3P" )
	}
	else
	{
		DeleteAnimEvent( player, "shift_core_use_meter" )
	}
	entity owner = weapon.GetWeaponOwner()
	if(!IsValid(owner))
		return
	array<string> Mods = owner.GetMainWeapons()[0].GetMods()
	Mods.fastremovebyvalue("RampageCore")
	owner.GetMainWeapons()[0].SetMods(Mods)
	foreach(entity weapon in owner.GetOffhandWeapons())
	{
		if(weapon.GetWeaponClassName() == "exrill_mp_titanweapon_rod_from_god")
			weapon.RemoveMod("RampageCore")
	}
}


void function Rampage_Core_UseMeter( entity player )
{
	if ( IsMultiplayer() )
		return

	entity soul = player.GetTitanSoul()
	float curTime = Time()
	float remainingTime = soul.GetCoreChargeExpireTime() - curTime

	if ( remainingTime > 0 )
	{
		const float USE_TIME = 5

		remainingTime = max( remainingTime - USE_TIME, 0 )
		float startTime = soul.GetCoreChargeStartTime()
		float duration = soul.GetCoreUseDuration()

		soul.SetTitanSoulNetFloat( "coreExpireFrac", remainingTime / duration )
		soul.SetTitanSoulNetFloatOverTime( "coreExpireFrac", 0.0, remainingTime )
		soul.SetCoreChargeExpireTime( remainingTime + curTime )
	}
}

void function Rampage_Core_UseMeter_NPC( entity npc )
{
	Rampage_Core_UseMeter( npc )
}
#endif