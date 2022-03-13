untyped


global function pp_OnWeaponActivate_titanweapon_energy_cannon
global function pp_OnWeaponPrimaryAttack_titanweapon_energy_cannon
global function pp_OnWeaponChargeLevelIncreased_titanweapon_energy_cannon
global function pp_GetTitanEnergy_cannonChargeLevel
global function pp_MpTitanWeapon_Energy_cannonInit
global function pp_OnWeaponStartZoomIn_titanweapon_energy_cannon
global function pp_OnWeaponStartZoomOut_titanweapon_energy_cannon
global function pp_OnWeaponOwnerChanged_titanweapon_energy_cannon
global function pp_OnProjectileCollision_titanweapon_energy_cannon
#if SERVER
global function pp_OnWeaponNpcPrimaryAttack_titanweapon_energy_cannon
#endif // #if SERVER

const INSTANT_SHOT_DAMAGE 				= 1200
//const INSTANT_SHOT_MAX_CHARGES		= 2 // can't change this without updating crosshair
//const INSTANT_SHOT_TIME_PER_CHARGE	= 0
const ENERGY_CANNON_PROJECTILE_SPEED			= 1

struct {
	float chargeDownSoundDuration = 1.0 //"charge_cooldown_time"
} file
void function pp_OnProjectileCollision_titanweapon_energy_cannon( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	print("testing")
	#if SERVER
		StartParticleEffectInWorld( GetParticleSystemIndex($"P_meteor_trap_EXP"), projectile.GetOrigin(), <0,0,0>)
		EmitSoundAtPosition( TEAM_UNASSIGNED, projectile.GetOrigin(), "incendiary_trap_explode_large" )
		#endif
}

void function pp_OnWeaponActivate_titanweapon_energy_cannon( entity weapon )
{
	file.chargeDownSoundDuration = expect float( weapon.GetWeaponInfoFileKeyField( "charge_cooldown_time" ) )
}

var function pp_OnWeaponPrimaryAttack_titanweapon_energy_cannon( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireEnergy_cannon( weapon, attackParams, true )
}

void function pp_MpTitanWeapon_Energy_cannonInit()
{
	#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.pp_mp_titanweapon_energy_cannon, OnHit_TitanWeaponEnergy_cannon )
	#endif
}
#if SERVER

void function OnHit_TitanWeaponEnergy_cannon( entity victim, var damageInfo )
{
	OnHit_TitanWeaponEnergy_cannon_Internal( victim, damageInfo )
}

void function OnHit_TitanWeaponEnergy_cannon_Internal( entity victim, var damageInfo )
{
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if ( !IsValid( inflictor ) )
		return
	if ( !inflictor.IsProjectile() )
		return
	int extraDamage = int( CalculateTitanSniperExtraDamage( inflictor, victim ) )
	float damage = DamageInfo_GetDamage( damageInfo )

	float f_extraDamage = float( extraDamage )

	bool isCritical = IsCriticalHit( DamageInfo_GetAttacker( damageInfo ), victim, DamageInfo_GetHitBox( damageInfo ), damage, DamageInfo_GetDamageType( damageInfo ) )

	if ( isCritical )
	{
		array<string> projectileMods = inflictor.ProjectileGetMods()
		if ( projectileMods.contains( "fd_upgrade_crit" ) )
			f_extraDamage *= 2.0
		else
			f_extraDamage *= expect float( inflictor.ProjectileGetWeaponInfoFileKeyField( "critical_hit_damage_scale" ) )
	}

	//Check to see if damage has been see to zero so we don't override it.
	if ( damage > 0 && extraDamage > 0 )
	{
		damage += f_extraDamage
		DamageInfo_SetDamage( damageInfo, damage )
	}

	float nearRange = 1000
	float farRange = 1500
	float nearScale = 0.5
	float farScale = 0

	if ( victim.IsTitan() )
		PushEntWithDamageInfoAndDistanceScale( victim, damageInfo, nearRange, farRange, nearScale, farScale, 0.25 )
}

var function pp_OnWeaponNpcPrimaryAttack_titanweapon_energy_cannon( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireEnergy_cannon( weapon, attackParams, false )
}
#endif // #if SERVER


bool function pp_OnWeaponChargeLevelIncreased_titanweapon_energy_cannon( entity weapon )
{
	#if CLIENT
		if ( InPrediction() && !IsFirstTimePredicted() )
			return true
	#endif

	int level = weapon.GetWeaponChargeLevel()
	int maxLevel = weapon.GetWeaponChargeLevelMax()

	if ( level == maxLevel )
		weapon.EmitWeaponSound( "Weapon_Titan_Energy_cannon_LevelTick_Final" )
	else
		weapon.EmitWeaponSound( "Weapon_Titan_Energy_cannon_LevelTick_" + level )

	return true
}


function FireEnergy_cannon( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired )
{
	int chargeLevel = pp_GetTitanEnergy_cannonChargeLevel( weapon )
	entity weaponOwner = weapon.GetWeaponOwner()
	bool weaponHasInstantShotMod = weapon.HasMod( "instant_shot" )
	if ( chargeLevel == 0 )
		return 0

	//printt( "GetTitanEnergy_cannonChargeLevel():", chargeLevel )

	if ( chargeLevel > 4 )
		weapon.EmitWeaponSound_1p3p( "Weapon_Titan_Sniper_Level_4_1P", "Weapon_Titan_Sniper_Level_4_3P" )
	else if ( chargeLevel > 3 || weaponHasInstantShotMod )
		weapon.EmitWeaponSound_1p3p( "Weapon_Titan_Sniper_Level_3_1P", "Weapon_Titan_Sniper_Level_3_3P" )
	else if ( chargeLevel > 2  )
		weapon.EmitWeaponSound_1p3p( "Weapon_Titan_Sniper_Level_2_1P", "Weapon_Titan_Sniper_Level_2_3P" )
	else
		weapon.EmitWeaponSound_1p3p( "Weapon_Titan_Sniper_Level_1_1P", "Weapon_Titan_Sniper_Level_1_3P" )

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 * chargeLevel )

	if ( chargeLevel > 5 )
	{
		weapon.SetAttackKickScale( 1.0 )
		weapon.SetAttackKickRollScale( 3.0 )
	}
	else if ( chargeLevel > 4 )
	{
		weapon.SetAttackKickScale( 0.75 )
		weapon.SetAttackKickRollScale( 2.5 )
	}
	else if ( chargeLevel > 3 )
	{
		weapon.SetAttackKickScale( 0.60 )
		weapon.SetAttackKickRollScale( 2.0 )
	}
	else if ( chargeLevel > 2 || weaponHasInstantShotMod )
	{
		weapon.SetAttackKickScale( 0.45 )
		weapon.SetAttackKickRollScale( 1.60 )
	}
	else if ( chargeLevel > 1 )
	{
		weapon.SetAttackKickScale( 0.30 )
		weapon.SetAttackKickRollScale( 1.35 )
	}
	else
	{
		weapon.SetAttackKickScale( 0.20 )
		weapon.SetAttackKickRollScale( 1.0 )
	}

	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	if ( !shouldCreateProjectile )
		return 1

	entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir,weapon.GetWeaponChargeFraction()+0.3, DF_GIB | DF_BULLET | DF_ELECTRICAL, DF_EXPLOSION | DF_RAGDOLL, playerFired, 0 )
	if ( bolt )
	{
		bolt.s.bulletsToFire <- chargeLevel

		bolt.s.extraDamagePerBullet <- weapon.GetWeaponSettingInt( eWeaponVar.damage_additional_bullets )
		bolt.s.extraDamagePerBullet_Titan <- weapon.GetWeaponSettingInt( eWeaponVar.damage_additional_bullets_titanarmor )

		if ( chargeLevel > 4 )
			bolt.SetProjectilTrailEffectIndex( 2 )
		else if ( chargeLevel > 2 )
			bolt.SetProjectilTrailEffectIndex( 1 )

		#if SERVER
			Assert( weaponOwner == weapon.GetWeaponOwner() )
			bolt.SetOwner( weaponOwner )
		#endif
	}

	return 1
}

int function pp_GetTitanEnergy_cannonChargeLevel( entity weapon )
{
	if ( !IsValid( weapon ) )
		return 0

	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return 0

	if ( !owner.IsPlayer() )
		return 3

	if ( !weapon.IsReadyToFire() )
		return 0

	int charges = weapon.GetWeaponChargeLevel()
	return (1 + charges)
}

void function pp_OnWeaponStartZoomIn_titanweapon_energy_cannon( entity weapon )
{
	#if SERVER
	if ( weapon.HasMod( "pas_northstar_optics" ) )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		if ( !IsValid( weaponOwner ) )
			return
		AddThreatScopeColorStatusEffect( weaponOwner )
	}
	#endif
}

void function pp_OnWeaponStartZoomOut_titanweapon_energy_cannon( entity weapon )
{
	#if SERVER
	if ( weapon.HasMod( "pas_northstar_optics" ) )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		if ( !IsValid( weaponOwner ) )
			return
		RemoveThreatScopeColorStatusEffect( weaponOwner )
	}
	#endif
}

void function pp_OnWeaponOwnerChanged_titanweapon_energy_cannon( entity weapon, WeaponOwnerChangedParams changeParams )
{
	#if SERVER
	if ( IsValid( changeParams.oldOwner ) && changeParams.oldOwner.IsPlayer() )
		RemoveThreatScopeColorStatusEffect( changeParams.oldOwner )
	#endif
}
