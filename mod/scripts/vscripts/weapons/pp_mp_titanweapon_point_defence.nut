untyped

global function pp_MpTitanAbilityHeatShield_Init

global function pp_OnWeaponActivate_titanweapon_pont_defence
global function pp_OnWeaponDeactivate_titanweapon_pont_defence
global function pp_OnWeaponCustomActivityStart_titanweapon_pont_defence
global function pp_OnWeaponVortexHitBullet_titanweapon_pont_defence
global function pp_OnWeaponVortexHitProjectile_titanweapon_pont_defence
global function pp_OnWeaponPrimaryAttack_titanweapon_pont_defence
global function pp_OnWeaponChargeBegin_titanweapon_pont_defence
global function pp_OnWeaponChargeEnd_titanweapon_pont_defence
global function pp_OnWeaponAttemptOffhandSwitch_titanweapon_pont_defence
global function pp_OnWeaponOwnerChanged_titanweapon_pont_defence

#if SERVER
global function pp_OnWeaponNpcPrimaryAttack_titanweapon_pont_defence
#endif
const VORTEX_SPHERE_COLOR_PAS_ION_VORTEX	= <115, 174, 255>	// blue
const asset pont_defence 				= $"P_wpn_meteor_exp"
const asset pont_defence_FP 				= $"P_wpn_meteor_exp"
const asset pont_defence_ABSORB_FX		= $"P_wpn_HeatShield_impact"
const asset pont_defence_IMPACT_TITAN 	= $"P_wpn_HeatSheild_burn_titan"
const asset pont_defence_IMPACT_HUMAN 	= $"P_wpn_HeatSheild_burn_human"
const SIGNAL_ID_BULLET_HIT_THINK = "signal_id_bullet_hit_think"
const ACTIVATION_COST_FRAC = 0.05
const int pont_defence_FOV = 120

function pp_MpTitanAbilityHeatShield_Init()
{
	HeatShieldPrecache()

	RegisterSignal( "HeatShieldEnd" )

}

function HeatShieldPrecache()
{
	PrecacheParticleSystem( $"P_impact_exp_emp_med_air" )

	//Heat Shield FX
	PrecacheParticleSystem( pont_defence )
	PrecacheParticleSystem( pont_defence_FP )
	PrecacheParticleSystem( pont_defence_ABSORB_FX )
	PrecacheParticleSystem( pont_defence_IMPACT_TITAN )
	PrecacheParticleSystem( pont_defence_IMPACT_HUMAN )

}

void function pp_OnWeaponOwnerChanged_titanweapon_pont_defence( entity weapon, WeaponOwnerChangedParams changeParams )
{
	if ( !( "initialized" in weapon.s ) )
	{
		weapon.s.fxChargingFPControlPoint <- pont_defence_FP
		weapon.s.fxChargingFPControlPointReplay <- pont_defence_FP
		weapon.s.fxChargingControlPoint <- pont_defence
		weapon.s.fxBulletHit <- pont_defence_ABSORB_FX

		weapon.s.fxChargingFPControlPointBurn <- pont_defence_FP
		weapon.s.fxChargingFPControlPointReplayBurn <- pont_defence_FP
		weapon.s.fxChargingControlPointBurn <- pont_defence
		weapon.s.fxBulletHitBurn <- pont_defence_ABSORB_FX

		weapon.s.fxElectricalExplosion <- $"P_impact_exp_emp_med_air"

		weapon.s.lastFireTime <- 0
		weapon.s.hadChargeWhenFired <- false

		#if CLIENT
			weapon.s.lastUseTime <- 0
		#endif

		weapon.s.initialized <- true
	}
}

void function pp_OnWeaponActivate_titanweapon_pont_defence( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	// just for NPCs (they don't do the deploy event)
	if ( !weaponOwner.IsPlayer() )
	{
		Assert( !( "isVortexing" in weaponOwner.s ), "NPC trying to vortex before cleaning up last vortex" )
		StartHeatShield( weapon )
	}
	else
	{
		PlayerUsedOffhand( weaponOwner, weapon )
	}
}

void function pp_OnWeaponDeactivate_titanweapon_pont_defence( entity weapon )
{
	EndVortex( weapon )
}

void function pp_OnWeaponCustomActivityStart_titanweapon_pont_defence( entity weapon )
{
	EndVortex( weapon )
}

function StartHeatShield( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	#if CLIENT
		if ( weaponOwner != GetLocalViewPlayer() )
			return
	if ( IsFirstTimePredicted() )
		Rumble_Play( "rumble_titan_heatshield_start", {} )
	#endif

	int sphereRadius = 120
	int bulletFOV = pont_defence_FOV

	ApplyActivationCost( weapon, ACTIVATION_COST_FRAC )

	if ( weapon.GetWeaponChargeFraction() < 1 )
	{
		weapon.s.hadChargeWhenFired = true
		CreateVortexSphere( weapon, false, false, sphereRadius, bulletFOV )
		EnablePointDefenceSphere( weapon )
	}
	else
	{
		weapon.s.hadChargeWhenFired = false
	}

	#if SERVER
		thread ForceReleaseOnPlayerEject( weapon )
	#endif

	#if CLIENT
		weapon.s.lastUseTime = Time()
	#endif
}
string function GetVortexTagName( entity weapon )
{
	if ( "vortexTagName" in weapon.s )
		return expect string( weapon.s.vortexTagName )

	return "vortex_center"
}

void function SetPlayerUsingVortex( entity weaponOwner, entity vortexWeapon )
{
	weaponOwner.EndSignal( "OnDeath" )

	weaponOwner.s.isVortexing <- true

	vortexWeapon.WaitSignal( "VortexStopping" )

	OnThreadEnd
	(
		function() : ( weaponOwner )
		{
			if ( IsValid_ThisFrame( weaponOwner ) && "isVortexing" in weaponOwner.s )
			{
				delete weaponOwner.s.isVortexing
			}
		}
	)
}
vector function GetBulletCollectionOffset( entity weapon )
{
	if ( "bulletCollectionOffset" in weapon.s )
		return expect vector( weapon.s.bulletCollectionOffset )

	entity owner = weapon.GetWeaponOwner()
	if ( owner.IsTitan() )
		return Vector( 300.0, -90.0, -70.0 )
	else
		return Vector( 80.0, 17.0, -11.0 )

	unreachable
}


function SetVortexAmmo( entity vortexWeapon, count )
{
	entity owner = vortexWeapon.GetWeaponOwner()
	if ( !IsValid_ThisFrame( owner ) )
		return
	#if CLIENT
		if ( !IsLocalViewPlayer( owner ) )
		return
	#endif

	vortexWeapon.SetWeaponPrimaryAmmoCount( count )
}
#if SERVER
void function Vortex_CreateAbsorbFX_ControlPoints( entity vortexWeapon )
{
	entity player = vortexWeapon.GetWeaponOwner()
	Assert( player )

	// vortex swirling incoming rounds FX location control point
	if ( !( "vortexBulletEffectCP" in vortexWeapon.s ) )
		vortexWeapon.s.vortexBulletEffectCP <- null
	vortexWeapon.s.vortexBulletEffectCP = CreateEntity( "info_placement_helper" )
	SetTargetName( expect entity( vortexWeapon.s.vortexBulletEffectCP ), UniqueString( "vortexBulletEffectCP" ) )
	vortexWeapon.s.vortexBulletEffectCP.kv.start_active = 1

	DispatchSpawn( vortexWeapon.s.vortexBulletEffectCP )

	vector offset = GetBulletCollectionOffset( vortexWeapon )
	vector origin = player.OffsetPositionFromView( player.EyePosition(), offset )

	vortexWeapon.s.vortexBulletEffectCP.SetOrigin( origin )
	vortexWeapon.s.vortexBulletEffectCP.SetParent( player )

	// vortex sphere color control point
	if ( !( "vortexSphereColorCP" in vortexWeapon.s ) )
		vortexWeapon.s.vortexSphereColorCP <- null
	vortexWeapon.s.vortexSphereColorCP = CreateEntity( "info_placement_helper" )
	SetTargetName( expect entity( vortexWeapon.s.vortexSphereColorCP ), UniqueString( "vortexSphereColorCP" ) )
	vortexWeapon.s.vortexSphereColorCP.kv.start_active = 1

	DispatchSpawn( vortexWeapon.s.vortexSphereColorCP )
}
#endif
void function EnablePointDefenceSphere( entity vortexWeapon )
{
	string tagname = GetVortexTagName( vortexWeapon )
	entity weaponOwner = vortexWeapon.GetWeaponOwner()
	local hasBurnMod = vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod )

	#if SERVER
		entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
		Assert( vortexSphere )
		vortexSphere.FireNow( "Enable" )

		thread SetPlayerUsingVortex( weaponOwner, vortexWeapon )

		Vortex_CreateAbsorbFX_ControlPoints( vortexWeapon )

		// world (3P) version of the vortex sphere FX
	#endif

	SetVortexAmmo( vortexWeapon, 0 )

	#if CLIENT
		if ( IsLocalViewPlayer( weaponOwner ) )
	{
		local fxAlias = null

		if ( hasBurnMod )
		{
			if ( "fxChargingFPControlPointBurn" in vortexWeapon.s )
				fxAlias = vortexWeapon.s.fxChargingFPControlPointBurn
		}
		else
		{
			if ( "fxChargingFPControlPoint" in vortexWeapon.s )
				fxAlias = vortexWeapon.s.fxChargingFPControlPoint
		}

	}
	#elseif  SERVER
		asset fxAlias = $""

		if ( hasBurnMod )
		{
			if ( "fxChargingFPControlPointReplayBurn" in vortexWeapon.s )
				fxAlias = expect asset( vortexWeapon.s.fxChargingFPControlPointReplayBurn )
		}
		else
		{
			if ( "fxChargingFPControlPointReplay" in vortexWeapon.s )
				fxAlias = expect asset( vortexWeapon.s.fxChargingFPControlPointReplay )
		}

	#endif
}
function ForceReleaseOnPlayerEject( entity weapon )
{
	weapon.EndSignal( "VortexFired" )
	weapon.EndSignal( "OnDestroy" )

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( !IsAlive( weaponOwner ) )
		return

	weaponOwner.EndSignal( "OnDeath" )

	weaponOwner.WaitSignal( "TitanEjectionStarted" )

	weapon.ForceRelease()
}

function ApplyActivationCost( entity weapon, float frac )
{
	float fracLeft = weapon.GetWeaponChargeFraction()

	if ( fracLeft + frac >= 1 )
	{
		weapon.ForceRelease()
		weapon.SetWeaponChargeFraction( 1.0 )
	}
	else
	{
		weapon.SetWeaponChargeFraction( fracLeft + frac )
	}
}

function EndVortex( entity weapon )
{
	#if CLIENT
		weapon.s.lastUseTime = Time()
	#endif
	DestroyPointDefenseSphereFromVortexWeapon( weapon )
}
function DestroyPointDefenseSphereFromVortexWeapon( entity vortexWeapon )
{
	DisablePointDefenseSphereFromVortexWeapon( vortexWeapon )

	#if SERVER
		DestroyPointDefenseSphere( vortexWeapon.GetWeaponUtilityEntity() )
		vortexWeapon.SetWeaponUtilityEntity( null )
	#endif
}
void function DestroyPointDefenseSphere( entity vortexSphere )
{
	if ( IsValid( vortexSphere ) )
	{
		vortexSphere.Destroy()
	}
}
void function DisableVortexSphere( entity vortexSphere )
{
	if ( IsValid( vortexSphere ) )
	{
		vortexSphere.FireNow( "Disable" )
		vortexSphere.Signal( SIGNAL_ID_BULLET_HIT_THINK )
	}

}

function DisablePointDefenseSphereFromVortexWeapon( entity vortexWeapon )
{
	vortexWeapon.Signal( "VortexStopping" )

	// server cleanup
	#if SERVER
		DisableVortexSphere( vortexWeapon.GetWeaponUtilityEntity() )
		vortexWeapon.w.vortexImpactData = []
	#endif
}

bool function pp_OnWeaponVortexHitBullet_titanweapon_pont_defence( entity weapon, entity vortexSphere, var damageInfo )
{
	#if CLIENT
		return true
	#else
		if ( !ValidateVortexImpact( vortexSphere ) )
			return false

		entity attacker				= DamageInfo_GetAttacker( damageInfo )
		vector origin				= DamageInfo_GetDamagePosition( damageInfo )
		int damageSourceID			= DamageInfo_GetDamageSourceIdentifier( damageInfo )
		entity attackerWeapon		= DamageInfo_GetWeapon( damageInfo )
		string attackerWeaponName	= attackerWeapon.GetWeaponClassName()

		local impactData = Vortex_CreateImpactEventData( weapon, attacker, origin, damageSourceID, attackerWeaponName, "hitscan" )
		VortexDrainedByImpact( weapon, attackerWeapon, null, null )
		if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
			return true
		//Vortex_SpawnHeatShieldPingFX( weapon, impactData, true )

		//Generate point defence projectile
		entity weaponOwner = weapon.GetWeaponOwner()
		int attachID = weaponOwner.LookupAttachment( "muzzle_flash" )
		vector attackPos = weaponOwner.GetAttachmentOrigin( attachID )
		
		vector dirToTarget = origin - attackPos
		dirToTarget = Normalize( dirToTarget )

		entity bolt = weapon.FireWeaponBolt(attackPos, dirToTarget, 1, damageTypes.gibBullet | DF_IMPACT | DF_EXPLOSION | DF_RAGDOLL | DF_KNOCK_BACK, DF_EXPLOSION | DF_RAGDOLL | DF_KNOCK_BACK, false, 0 )

		return true
	#endif
}

bool function pp_OnWeaponVortexHitProjectile_titanweapon_pont_defence( entity weapon, entity vortexSphere, entity attacker, entity projectile, vector contactPos )
{
	#if CLIENT
		return true
	#else
		if ( !ValidateVortexImpact( vortexSphere, projectile ) )
			return false

		int damageSourceID = projectile.ProjectileGetDamageSourceID()
		string weaponName = projectile.ProjectileGetWeaponClassName()

		local impactData = Vortex_CreateImpactEventData( weapon, attacker, contactPos, damageSourceID, weaponName, "projectile" )
		VortexDrainedByImpact( weapon, projectile, projectile, null )
		if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
			return true
		//Vortex_SpawnHeatShieldPingFX( weapon, impactData, false )

		//Generate point defence projectile
		entity weaponOwner = weapon.GetWeaponOwner()
		int attachID = weaponOwner.LookupAttachment( "muzzle_flash" )
		vector attackPos = weaponOwner.GetAttachmentOrigin( attachID )
		vector dirToTarget = contactPos - attackPos
		dirToTarget = Normalize( dirToTarget )

		entity bolt = weapon.FireWeaponBolt( attackPos, dirToTarget, 1, damageTypes.gibBullet | DF_IMPACT | DF_EXPLOSION | DF_RAGDOLL | DF_KNOCK_BACK, DF_EXPLOSION | DF_RAGDOLL | DF_KNOCK_BACK, false, 0 )

		return true
	#endif
}

var function pp_OnWeaponPrimaryAttack_titanweapon_pont_defence( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponSound_1p3p( "pont_defence_1p_end", "pont_defence_3p_end" )
	FadeOutSoundOnEntity( weapon, "pont_defence_1p_start", 0.15 )
	FadeOutSoundOnEntity( weapon, "pont_defence_3p_start", 0.15 )
	return 0
}

#if SERVER
var function pp_OnWeaponNpcPrimaryAttack_titanweapon_pont_defence( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponSound_1p3p( "pont_defence_1p_end", "pont_defence_3p_end" )
	return 0
}
#endif

bool function pp_OnWeaponChargeBegin_titanweapon_pont_defence( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		StartHeatShield( weapon )

	return true
}

#if SERVER

bool function HasRecentlyRodeoedTitan( entity pilot, entity titan )
{
	if ( GetEnemyRodeoPilot( titan ) == pilot )
		return true

	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return false

	if ( soul.e.lastRodeoAttacker == pilot )
	{
		if ( Time() - soul.GetLastRodeoHitTime() > 0.4 )
			return false
		else
			return true
	}

	return false
}
#endif

void function pp_OnWeaponChargeEnd_titanweapon_pont_defence( entity weapon )
{
	weapon.Signal( "HeatShieldEnd" )
}

bool function pp_OnWeaponAttemptOffhandSwitch_titanweapon_pont_defence( entity weapon )
{
	return weapon.GetWeaponChargeFraction() < 0.8
}